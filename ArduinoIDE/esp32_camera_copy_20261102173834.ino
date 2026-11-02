/* Includes ---------------------------------------------------------------- */
#include <BATTLES_inferencing.h>
#include "edge-impulse-sdk/dsp/image/image.hpp"

#include "esp_camera.h"
#include <Wire.h>
#include <U8g2lib.h>
#include <ESP32Servo.h>

#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include "mbedtls/md.h"   // HMAC-SHA256 for signed claim codes

// Select camera model - AI Thinker has PSRAM
#define CAMERA_MODEL_AI_THINKER 

#if defined(CAMERA_MODEL_AI_THINKER)
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM     0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27

#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM       5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22
#else
#error "Camera model not selected"
#endif

/* Constant defines -------------------------------------------------------- */
#define EI_CAMERA_RAW_FRAME_BUFFER_COLS         320
#define EI_CAMERA_RAW_FRAME_BUFFER_ROWS         240
#define EI_CAMERA_FRAME_BYTE_SIZE               3

#define I2C_SDA 15
#define I2C_SCL 14
#define SERVO_PIN 12 

// Stable U8g2 OLED configuration for 128x64 display on custom ESP32 pins
U8G2_SH1106_128X64_NONAME_1_HW_I2C u8g2(U8G2_R0, /* reset=*/ U8X8_PIN_NONE);

Servo myServo; 

/* Private variables ------------------------------------------------------- */
static bool debug_nn = false; 
static bool is_initialised = false;
uint8_t *snapshot_buf; 
bool oledConnected = false; 

// Updated States for Multi-Item Batching & Points
enum SystemState { WAITING_FOR_TRASH, COLLECTING_SESSION, SHOWING_CODE };
SystemState currentState = WAITING_FOR_TRASH;

String detectedType = ""; 
int bottleCount = 0;
int wasteCount = 0;
unsigned long sessionTimer = 0;
unsigned long lastDetectTime = 0;

const unsigned long sessionTimeout = 10000;    // 10-second window to drop more items
const unsigned long dropCooldown = 2500;       // Cooldown between individual drops to prevent double-counting
const unsigned long codeDisplayDuration = 15000; // Show points & code for 15 seconds before resetting
long randomCode = 0;

// ---- Signed claim code ---------------------------------------------------
static const char CLAIM_SECRET[] = "SmartBin-CHANGE-ME-2026";
const int MAX_ITEMS_PER_CODE = 99;

static int claimCheck(int items, int nonce) {
    char msg[12];
    snprintf(msg, sizeof(msg), "%02d:%03d", items, nonce);

    uint8_t mac[32];
    mbedtls_md_context_t ctx;
    mbedtls_md_init(&ctx);
    mbedtls_md_setup(&ctx, mbedtls_md_info_from_type(MBEDTLS_MD_SHA256), 1);
    mbedtls_md_hmac_starts(&ctx, (const unsigned char *)CLAIM_SECRET, strlen(CLAIM_SECRET));
    mbedtls_md_hmac_update(&ctx, (const unsigned char *)msg, strlen(msg));
    mbedtls_md_hmac_finish(&ctx, mac);
    mbedtls_md_free(&ctx);

    uint32_t v = ((uint32_t)mac[0] << 24) | ((uint32_t)mac[1] << 16) |
                 ((uint32_t)mac[2] << 8)  |  (uint32_t)mac[3];
    return (int)(v % 1000);
}

static long makeClaimCode(int items, int nonce) {
    return (long)items * 1000000L + (long)nonce * 1000L + claimCheck(items, nonce);
}

static camera_config_t camera_config = {
    .pin_pwdn = PWDN_GPIO_NUM,
    .pin_reset = RESET_GPIO_NUM,
    .pin_xclk = XCLK_GPIO_NUM,
    .pin_sscb_sda = SIOD_GPIO_NUM,
    .pin_sscb_scl = SIOC_GPIO_NUM,

    .pin_d7 = Y9_GPIO_NUM,
    .pin_d6 = Y8_GPIO_NUM,
    .pin_d5 = Y7_GPIO_NUM,
    .pin_d4 = Y6_GPIO_NUM,
    .pin_d3 = Y5_GPIO_NUM,
    .pin_d2 = Y4_GPIO_NUM,
    .pin_d1 = Y3_GPIO_NUM,
    .pin_d0 = Y2_GPIO_NUM,
    .pin_vsync = VSYNC_GPIO_NUM,
    .pin_href = HREF_GPIO_NUM,
    .pin_pclk = PCLK_GPIO_NUM,

    .xclk_freq_hz = 20000000,
    .ledc_timer = LEDC_TIMER_0,
    .ledc_channel = LEDC_CHANNEL_0,

    .pixel_format = PIXFORMAT_JPEG, 
    .frame_size = FRAMESIZE_QVGA,    

    .jpeg_quality = 12, 
    .fb_count = 1,       
    .fb_location = CAMERA_FB_IN_PSRAM,
    .grab_mode = CAMERA_GRAB_WHEN_EMPTY,
};

bool ei_camera_init(void);
void ei_camera_deinit(void);
bool ei_camera_capture(uint32_t img_width, uint32_t img_height, uint8_t *out_buf);
static int ei_camera_get_data(size_t offset, size_t length, float *out_ptr);

// Helper function for standard status screens
void drawOledScreen(String line1, String line2 = "", String line3 = "") {
    if (!oledConnected) return;
    u8g2.firstPage();
    do {
        u8g2.setFont(u8g2_font_ncenB08_tr);
        if (line1.length() > 0) u8g2.drawStr(0, 15, line1.c_str());
        if (line2.length() > 0) u8g2.drawStr(0, 35, line2.c_str());
        if (line3.length() > 0) u8g2.drawStr(0, 55, line3.c_str());
    } while (u8g2.nextPage());
}

// Helper function specifically for displaying final points and large claim code
void drawRewardScreen(int totalItems, int points, long code) {
    if (!oledConnected) return;
    char codeBuf[12];
    sprintf(codeBuf, "%04ld %04ld", code / 10000, code % 10000);
    
    u8g2.firstPage();
    do {
        u8g2.setFont(u8g2_font_ncenB08_tr);
        u8g2.drawStr(0, 12, "REWARD CODE READY");
        
        char infoBuf[30];
        sprintf(infoBuf, "Items:%d  Earned:%d Pts", totalItems, points);
        u8g2.drawStr(0, 28, infoBuf);
        
        u8g2.setFont(u8g2_font_ncenB14_tr);
        u8g2.drawStr(4, 52, codeBuf);
    } while (u8g2.nextPage());
}

void setup()
{
    WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
    Serial.begin(115200);

    delay(800); 

    Wire.begin(I2C_SDA, I2C_SCL, 100000);
    u8g2.begin();
    oledConnected = true;
    
    drawOledScreen("Smart Bin Ready!", "Bottle: 5pts | Waste: 1pt", "Drop trash to earn!");
    Serial.println(F("OLED Initialized Successfully with U8g2!"));

    myServo.attach(SERVO_PIN);
    myServo.write(90); 

    if (ei_camera_init() == false) {
        ei_printf("Failed to initialize Camera!\r\n");
    } else {
        ei_printf("Camera initialized\r\n");
    }

    ei_sleep(2000);
}

void loop()
{
    if (ei_sleep(5) != EI_IMPULSE_OK) {
        return;
    }

    // STATE 3: Showing reward code and points summary
    if (currentState == SHOWING_CODE) {
        myServo.write(90); 
        if ((millis() - sessionTimer) >= codeDisplayDuration) {
            bottleCount = 0;
            wasteCount = 0;
            currentState = WAITING_FOR_TRASH;
            drawOledScreen("Smart Bin Ready!", "Bottle: 5pts | Waste: 1pt", "Drop trash to earn!");
        }
        return; 
    }

    snapshot_buf = (uint8_t*)malloc(EI_CAMERA_RAW_FRAME_BUFFER_COLS * EI_CAMERA_RAW_FRAME_BUFFER_ROWS * EI_CAMERA_FRAME_BYTE_SIZE);

    if(snapshot_buf == nullptr) {
        return;
    }

    ei::signal_t signal;
    signal.total_length = EI_CLASSIFIER_INPUT_WIDTH * EI_CLASSIFIER_INPUT_HEIGHT;
    signal.get_data = &ei_camera_get_data;

    if (ei_camera_capture((size_t)EI_CLASSIFIER_INPUT_WIDTH, (size_t)EI_CLASSIFIER_INPUT_HEIGHT, snapshot_buf) == false) {
        free(snapshot_buf);
        return;
    }

    ei_impulse_result_t result = { 0 };

    EI_IMPULSE_ERROR err = run_classifier(&signal, &result, debug_nn);
    if (err != EI_IMPULSE_OK) {
        free(snapshot_buf);
        return;
    }

    bool itemDetectedThisFrame = false;
    String currentFrameLabel = "WASTE"; 

#if EI_CLASSIFIER_OBJECT_DETECTION == 1
    for (uint32_t i = 0; i < result.bounding_boxes_count; i++) {
        ei_impulse_result_bounding_box_t bb = result.bounding_boxes[i];
        
        if (bb.value < 0.85 || (bb.x < 20 && bb.y < 20)) {
            continue;
        }

        if (strcmp(bb.label, "BACKGROUND_BOX") == 0 || strcmp(bb.label, "background") == 0) {
            continue;
        }

        if (strcmp(bb.label, "BOTTLE") == 0 || strcmp(bb.label, "bottle") == 0) {
            itemDetectedThisFrame = true;
            currentFrameLabel = "BOTTLE";
            break; 
        }
    }
#else
    float maxVal = 0;
    int bestIndex = -1;
    for (uint16_t i = 0; i < EI_CLASSIFIER_LABEL_COUNT; i++) {
        if (result.classification[i].value > maxVal) {
            maxVal = result.classification[i].value;
            bestIndex = i;
        }
    }
    if (maxVal > 0.80) {
        itemDetectedThisFrame = true;
        String label = String(ei_classifier_inferencing_categories[bestIndex]);
        if (label == "BOTTLE" || label == "bottle") {
            currentFrameLabel = "BOTTLE";
        } else {
            currentFrameLabel = "WASTE";
        }
    }
#endif

    if (!itemDetectedThisFrame && result.bounding_boxes_count > 0) {
        itemDetectedThisFrame = true;
        currentFrameLabel = "WASTE";
    }

    free(snapshot_buf);

    // STATE 1: Waiting for the first item
    if (currentState == WAITING_FOR_TRASH) {
        if (itemDetectedThisFrame) {
            detectedType = currentFrameLabel;
            
            if (detectedType == "BOTTLE") {
                bottleCount = 1;
                myServo.write(0);   // Bottle Bin
                delay(1000);        
                myServo.write(90);  // Center
            } else {
                wasteCount = 1;
                myServo.write(180); // Waste Bin
                delay(1000);        
                myServo.write(90);  // Center
            }

            sessionTimer = millis();
            lastDetectTime = millis();
            currentState = COLLECTING_SESSION;
            
            int initialPoints = (bottleCount * 5) + (wasteCount * 1);
            drawOledScreen("Item Sorted (+5s)", "Type: " + detectedType, "Total Pts: " + String(initialPoints));
        }
    } 
    // STATE 2: Collecting additional items during session window
    else if (currentState == COLLECTING_SESSION) {
        if ((millis() - sessionTimer) >= sessionTimeout) {
            int totalItems = bottleCount + wasteCount;
            if (totalItems > MAX_ITEMS_PER_CODE) totalItems = MAX_ITEMS_PER_CODE;
            
            int totalPoints = (bottleCount * 5) + (wasteCount * 1);

            int nonce = (int)(esp_random() % 1000);
            // Note: Signed code tracks total items count for length consistency, 
            // while points are calculated cleanly using your formulas.
            randomCode = makeClaimCode(totalItems, nonce);
            Serial.printf("Claim code: %08ld (Bottles=%d, Waste=%d, Pts=%d)\n", randomCode, bottleCount, wasteCount, totalPoints);

            drawRewardScreen(totalItems, totalPoints, randomCode);

            currentState = SHOWING_CODE;
            sessionTimer = millis(); 
        } 
        else if (itemDetectedThisFrame) {
            if ((millis() - lastDetectTime) >= dropCooldown) {
                detectedType = currentFrameLabel;

                if (detectedType == "BOTTLE") {
                    bottleCount++;
                    myServo.write(0);   
                    delay(1000);        
                    myServo.write(90);  
                } else {
                    wasteCount++;
                    myServo.write(180); 
                    delay(1000);        
                    myServo.write(90);  
                }

                sessionTimer = millis();
                lastDetectTime = millis();

                int currentPoints = (bottleCount * 5) + (wasteCount * 1);
                char line2Buf[30];
                sprintf(line2Buf, "Bottles:%d | Waste:%d", bottleCount, wasteCount);
                char line3Buf[30];
                sprintf(line3Buf, "Current Pts: %d", currentPoints);
                
                drawOledScreen("Item Added! (+5s)", line2Buf, line3Buf);
            }
        }
    }
}

bool ei_camera_init(void) {
    if (is_initialised) return true;

    esp_err_t err = esp_camera_init(&camera_config);
    if (err != ESP_OK) {
      Serial.printf("Camera init failed with error 0x%x\n", err);
      return false;
    }

    sensor_t *s = esp_camera_sensor_get();
    if (s->id.PID == OV3660_PID) {
      s->set_vflip(s, 1); 
      s->set_brightness(s, 1); 
      s->set_saturation(s, 0); 
    }

    is_initialised = true;
    return true;
}

void ei_camera_deinit(void) {
    esp_err_t err = esp_camera_deinit();
    if (err != ESP_OK) {
        ei_printf("Camera deinit failed\n");
        return;
    }
    is_initialised = false;
}

bool ei_camera_capture(uint32_t img_width, uint32_t img_height, uint8_t *out_buf) {
    bool do_resize = false;

    if (!is_initialised) {
        ei_printf("ERR: Camera is not initialized\r\n");
        return false;
    }

    camera_fb_t *fb = esp_camera_fb_get();

    if (!fb) {
        ei_printf("Camera capture failed\n");
        return false;
    }

    bool converted = fmt2rgb888(fb->buf, fb->len, PIXFORMAT_JPEG, snapshot_buf);
    esp_camera_fb_return(fb);

    if(!converted){
       ei_printf("Conversion failed\n");
       return false;
    }

    if ((img_width != EI_CAMERA_RAW_FRAME_BUFFER_COLS) || (img_height != EI_CAMERA_RAW_FRAME_BUFFER_ROWS)) {
        do_resize = true;
    }

    if (do_resize) {
        ei::image::processing::crop_and_interpolate_rgb888(
        out_buf,
        EI_CAMERA_RAW_FRAME_BUFFER_COLS,
        EI_CAMERA_RAW_FRAME_BUFFER_ROWS,
        out_buf,
        img_width,
        img_height);
    }

    return true;
}

static int ei_camera_get_data(size_t offset, size_t length, float *out_ptr)
{
    size_t pixel_ix = offset * 3;
    size_t pixels_left = length;
    size_t out_ptr_ix = 0;

    while (pixels_left != 0) {
        out_ptr[out_ptr_ix] = (snapshot_buf[pixel_ix + 2] << 16) + (snapshot_buf[pixel_ix + 1] << 8) + snapshot_buf[pixel_ix];
        out_ptr_ix++;
        pixel_ix+=3;
        pixels_left--;
    }
    return 0;
}

#if !defined(EI_CLASSIFIER_SENSOR) || EI_CLASSIFIER_SENSOR != EI_CLASSIFIER_SENSOR_CAMERA
#error "Invalid model for current sensor"
#endif