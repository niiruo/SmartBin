/// Shared secret used to sign claim codes.
/// MUST be identical to CLAIM_SECRET in firmware/esp32_camera.ino.
const String kClaimSecret = 'SmartBin-CHANGE-ME-2026';

/// Must match the "* 3" in the firmware.
const int kPointsPerItem = 3;
const int kMaxItemsPerCode = 99;

/// Points a brand-new account starts with (your Python prototype used 50).
const int kStartingPoints = 0;

/// Wrong-code protection (stored on the device).
const int kMaxFailedAttempts = 5;
const Duration kLockoutDuration = Duration(minutes: 5);

/// Coupons offered on the dashboard.
const List<int> kCouponCosts = [20, 50];
