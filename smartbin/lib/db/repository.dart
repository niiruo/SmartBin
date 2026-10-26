import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../config.dart';
import '../services/claim_code.dart';
import 'app_database.dart';

/// A user-facing error. `message` is safe to show in the UI.
class AppException implements Exception {
  AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;

  String get fullName => '$firstName $lastName'.trim();

  factory AppUser.fromMap(Map<String, Object?> m) => AppUser(
        id: m['id'] as int,
        firstName: m['first_name'] as String,
        lastName: m['last_name'] as String,
        email: m['email'] as String,
        phone: m['phone'] as String,
      );
}

class ActivityItem {
  const ActivityItem({
    required this.kind,
    required this.amount,
    required this.items,
    required this.note,
    required this.createdAt,
  });

  final String kind; // claim | coupon | bonus
  final int amount;
  final int? items;
  final String? note;
  final DateTime createdAt;

  String get title {
    switch (kind) {
      case 'claim':
        return '${items ?? 0} item${items == 1 ? '' : 's'} recycled';
      case 'coupon':
        return note ?? 'Coupon';
      default:
        return note ?? 'Bonus';
    }
  }
}

class ClaimOutcome {
  const ClaimOutcome(
      {required this.items, required this.points, required this.balance});
  final int items;
  final int points;
  final int balance;
}

class Repository {
  Future<Database> get _db => AppDatabase.instance.database;

  // ---------------------------------------------------------------- helpers

  static final _rng = Random.secure();

  String _newSalt() =>
      base64.encode(List<int>.generate(16, (_) => _rng.nextInt(256)));

  /// Salted, iterated SHA-256. Fine for a local-only app; if you ever add a
  /// server, let the server do proper password hashing (argon2/bcrypt).
  String _hash(String password, String salt) {
    List<int> bytes = utf8.encode('$salt:$password');
    for (var i = 0; i < 5000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64.encode(bytes);
  }

  Future<String?> _getKv(DatabaseExecutor d, String name) async {
    final rows = await d.query('kv', where: 'name = ?', whereArgs: [name]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _setKv(DatabaseExecutor d, String name, String value) =>
      d.insert('kv', {'name': name, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<int> _balance(DatabaseExecutor d, int userId) async {
    final rows = await d.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS b FROM transactions WHERE user_id = ?',
        [userId]);
    return (rows.first['b'] as int?) ?? 0;
  }

  Future<AppUser?> _userById(DatabaseExecutor d, int id) async {
    final rows = await d.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  String _cleanEmail(String email) => email.trim().toLowerCase();

  // ------------------------------------------------------------------- auth

  Future<AppUser?> restoreSession() async {
    final d = await _db;
    final id = int.tryParse(await _getKv(d, 'session_user_id') ?? '');
    return id == null ? null : _userById(d, id);
  }

  Future<AppUser> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final d = await _db;
    final salt = _newSalt();
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final id = await d.transaction((txn) async {
        final id = await txn.insert('users', {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'email': _cleanEmail(email),
          'phone': '',
          'password_hash': _hash(password, salt),
          'salt': salt,
          'created_at': now,
        });
        if (kStartingPoints > 0) {
          await txn.insert('transactions', {
            'user_id': id,
            'kind': 'bonus',
            'amount': kStartingPoints,
            'note': 'Welcome bonus',
            'created_at': now,
          });
        }
        return id;
      });
      await _setKv(d, 'session_user_id', '$id');
      return (await _userById(d, id))!;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw AppException('An account with this email already exists.');
      }
      rethrow;
    }
  }

  Future<AppUser> logIn(String email, String password) async {
    final d = await _db;
    final rows = await d.query('users',
        where: 'email = ?', whereArgs: [_cleanEmail(email)]);
    if (rows.isEmpty ||
        _hash(password, rows.first['salt'] as String) !=
            rows.first['password_hash']) {
      throw AppException('Incorrect email or password.');
    }
    final user = AppUser.fromMap(rows.first);
    await _setKv(d, 'session_user_id', '${user.id}');
    return user;
  }

  Future<void> logOut() async {
    final d = await _db;
    await d.delete('kv', where: 'name = ?', whereArgs: ['session_user_id']);
  }

  Future<void> changePassword(int userId, String newPassword) async {
    final d = await _db;
    final salt = _newSalt();
    await d.update(
        'users', {'password_hash': _hash(newPassword, salt), 'salt': salt},
        where: 'id = ?', whereArgs: [userId]);
  }

  /// Offline "forgot password": there is no email server, so the new password
  /// is set directly on this device. Anyone holding the phone can use it.
  Future<void> resetPasswordByEmail(String email, String newPassword) async {
    final d = await _db;
    final rows = await d.query('users',
        columns: ['id'], where: 'email = ?', whereArgs: [_cleanEmail(email)]);
    if (rows.isEmpty) {
      throw AppException('No account on this device uses that email.');
    }
    await changePassword(rows.first['id'] as int, newPassword);
  }

  Future<AppUser> updateProfile({
    required int userId,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final d = await _db;
    await d.update(
        'users',
        {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'phone': phone.trim(),
        },
        where: 'id = ?',
        whereArgs: [userId]);
    return (await _userById(d, userId))!;
  }

  // ----------------------------------------------------------------- points

  Future<int> balance(int userId) async => _balance(await _db, userId);

  Future<List<ActivityItem>> recentActivity(int userId, {int limit = 10}) async {
    final d = await _db;
    final rows = await d.query('transactions',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'id DESC',
        limit: limit);
    return rows
        .map((r) => ActivityItem(
              kind: r['kind'] as String,
              amount: r['amount'] as int,
              items: r['items'] as int?,
              note: r['note'] as String?,
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
            ))
        .toList();
  }

  /// Validates the code the bin showed, then stores it and credits the points.
  Future<ClaimOutcome> redeemCode({
    required int userId,
    required String raw,
  }) async {
    final d = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final lockedUntil = int.tryParse(await _getKv(d, 'locked_until') ?? '') ?? 0;
    if (lockedUntil > now) {
      final mins = ((lockedUntil - now) / 60000).ceil();
      throw AppException(
          'Too many wrong codes. Try again in $mins minute${mins == 1 ? '' : 's'}.');
    }

    final claim = ClaimCode.tryParse(raw);
    if (claim == null) {
      await _registerFailure(d, now);
      throw AppException(
          'That code is not valid. Check the 8 digits on the bin screen.');
    }

    try {
      final outcome = await d.transaction((txn) async {
        // Throws a unique-constraint error if this code was ever used before.
        await txn.insert('used_codes', {'code': claim.digits, 'used_at': now});
        await txn.insert('transactions', {
          'user_id': userId,
          'kind': 'claim',
          'amount': claim.points,
          'items': claim.items,
          'code': claim.digits,
          'note': 'Bin code ${claim.digits}',
          'created_at': now,
        });
        final bal = await _balance(txn, userId);
        return ClaimOutcome(
            items: claim.items, points: claim.points, balance: bal);
      });
      await _setKv(d, 'fail_count', '0');
      return outcome;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw AppException('This code has already been redeemed.');
      }
      rethrow;
    }
  }

  Future<void> _registerFailure(DatabaseExecutor d, int now) async {
    final count = (int.tryParse(await _getKv(d, 'fail_count') ?? '') ?? 0) + 1;
    if (count >= kMaxFailedAttempts) {
      await _setKv(d, 'fail_count', '0');
      await _setKv(d, 'locked_until',
          '${now + kLockoutDuration.inMilliseconds}');
    } else {
      await _setKv(d, 'fail_count', '$count');
    }
  }

  // ---------------------------------------------------------- delete account

  /// Permanently removes the account and everything tied to it (points,
  /// activity, coupons). Needs the current password. Redeemed bin codes stay
  /// in `used_codes`, so they can't be claimed again on a new account.
  Future<void> deleteAccount({
    required int userId,
    required String password,
  }) async {
    final d = await _db;
    final rows = await d.query('users', where: 'id = ?', whereArgs: [userId]);
    if (rows.isEmpty) throw AppException('Account not found.');
    if (_hash(password, rows.first['salt'] as String) !=
        rows.first['password_hash']) {
      throw AppException('Incorrect password.');
    }
    await d.transaction((txn) async {
      await txn.delete('transactions', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('coupons', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('users', where: 'id = ?', whereArgs: [userId]);
      await txn.delete('kv', where: 'name = ?', whereArgs: ['session_user_id']);
    });
  }

  // ---------------------------------------------------------------- coupons

  /// Spends [cost] points and returns the new coupon code.
  Future<String> buyCoupon({required int userId, required int cost}) async {
    final d = await _db;
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code = 'SB-$cost-'
        '${List.generate(6, (_) => alphabet[_rng.nextInt(alphabet.length)]).join()}';
    final now = DateTime.now().millisecondsSinceEpoch;

    return d.transaction((txn) async {
      if (await _balance(txn, userId) < cost) {
        throw AppException('You do not have enough points.');
      }
      await txn.insert('transactions', {
        'user_id': userId,
        'kind': 'coupon',
        'amount': -cost,
        'note': 'Coupon $code',
        'created_at': now,
      });
      await txn.insert('coupons', {
        'user_id': userId,
        'cost': cost,
        'code': code,
        'created_at': now,
      });
      return code;
    });
  }
}
