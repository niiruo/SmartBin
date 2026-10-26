import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../config.dart';

/// An 8-digit claim code printed by the bin:  [items:2][nonce:3][check:3]
///
///  - items : how many items were sorted in the session (01-99)
///  - nonce : random number from the ESP32 so two sessions differ
///  - check : first 4 bytes of HMAC-SHA256("II:NNN", secret) mod 1000
///
/// Because the check digits depend on a secret shared by the bin and the app,
/// the app can verify a code completely offline and read the points out of it.
class ClaimCode {
  const ClaimCode._(this.digits, this.items, this.nonce);

  /// Normalised 8 digits, e.g. "03456750". This is what gets stored.
  final String digits;
  final int items;
  final int nonce;

  int get points => items * kPointsPerItem;

  /// Strips spaces/dashes so "0345 6750" and "03456750" are the same code.
  static String normalize(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  static int checkDigits(int items, int nonce, {String secret = kClaimSecret}) {
    final msg =
        '${items.toString().padLeft(2, '0')}:${nonce.toString().padLeft(3, '0')}';
    final mac =
        Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(msg)).bytes;
    final v = mac[0] * 16777216 + mac[1] * 65536 + mac[2] * 256 + mac[3];
    return v % 1000;
  }

  /// Returns null when the code is malformed or the check digits are wrong.
  static ClaimCode? tryParse(String raw, {String secret = kClaimSecret}) {
    final d = normalize(raw);
    if (d.length != 8) return null;
    final items = int.parse(d.substring(0, 2));
    final nonce = int.parse(d.substring(2, 5));
    final check = int.parse(d.substring(5, 8));
    if (items < 1 || items > kMaxItemsPerCode) return null;
    if (check != checkDigits(items, nonce, secret: secret)) return null;
    return ClaimCode._(d, items, nonce);
  }
}
