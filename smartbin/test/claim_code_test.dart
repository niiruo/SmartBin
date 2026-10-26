import 'package:flutter_test/flutter_test.dart';
import 'package:smartbin/services/claim_code.dart';

// Reference codes computed independently (Python hmac/hashlib) with the
// default secret "SmartBin-CHANGE-ME-2026". If you change the secret in
// lib/config.dart, regenerate these.
void main() {
  const vectors = {
    '01000834': [1, 0],
    '01123349': [1, 123],
    '03456750': [3, 456],
    '05789944': [5, 789],
    '12999095': [12, 999],
    '99007569': [99, 7],
  };

  test('accepts valid codes and reads items/points out of them', () {
    vectors.forEach((digits, v) {
      final c = ClaimCode.tryParse(digits);
      expect(c, isNotNull, reason: digits);
      expect(c!.items, v[0]);
      expect(c.nonce, v[1]);
      expect(c.points, v[0] * 3);
      expect(c.digits, digits);
    });
  });

  test('accepts spaces and dashes as typed from the OLED', () {
    expect(ClaimCode.tryParse('0345 6750')?.items, 3);
    expect(ClaimCode.tryParse('0345-6750')?.items, 3);
  });

  test('rejects a wrong check digit', () {
    expect(ClaimCode.tryParse('03456751'), isNull);
    expect(ClaimCode.tryParse('03456749'), isNull);
  });

  test('rejects tampered item count (cannot inflate points)', () {
    // Same nonce+check as 03456750 but claims 30 items.
    expect(ClaimCode.tryParse('30456750'), isNull);
  });

  test('rejects wrong length, zero items and junk', () {
    expect(ClaimCode.tryParse(''), isNull);
    expect(ClaimCode.tryParse('1234567'), isNull);
    expect(ClaimCode.tryParse('012345678'), isNull);
    expect(ClaimCode.tryParse('00000000'), isNull);
    expect(ClaimCode.tryParse('abcdefgh'), isNull);
  });
}
