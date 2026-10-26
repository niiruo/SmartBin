# Smart Bin (Flutter, offline)

## Set up

```bash
flutter create smartbin          # project name must be "smartbin"
cd smartbin
flutter pub add sqflite path crypto
# copy this zip's lib/ and test/ over the generated ones
flutter test                     # checks the claim-code verifier
flutter run
```

Your logo and avatar (optional; icons show until you add them):

1. Put `smartbin_logo.png` and `profile.png` in `assets/`
2. In `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/
   ```

Flash `firmware/esp32_camera.ino` to the ESP32 in place of your old sketch.

## Claim codes

The bin shows 8 digits: `[items:2][nonce:3][check:3]`.
`check` = HMAC-SHA256("II:NNN", secret), first 4 bytes, mod 1000.

The secret must be identical in two places:
- `CLAIM_SECRET` in `firmware/esp32_camera.ino`
- `kClaimSecret` in `lib/config.dart`

Change it from the default before you ship. If you change it, regenerate the
vectors in `test/claim_code_test.dart`.

Also keep in sync: points per item (`* 3` in firmware, `kPointsPerItem` in app).

## Database (SQLite, on-device)

| table | purpose |
|---|---|
| users | account + salted password hash |
| transactions | every points change; balance = SUM(amount); `code` is UNIQUE so a bin code redeems once |
| coupons | coupons bought with points |
| kv | logged-in user, wrong-code counter, lockout |
