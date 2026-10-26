import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens the on-device SQLite file. Nothing here touches the network.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'smartbin.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name    TEXT NOT NULL,
        last_name     TEXT NOT NULL,
        email         TEXT NOT NULL UNIQUE COLLATE NOCASE,
        phone         TEXT NOT NULL DEFAULT '',
        password_hash TEXT NOT NULL,
        salt          TEXT NOT NULL,
        created_at    INTEGER NOT NULL
      )''');

    // One row per points change. Balance = SUM(amount).
    // `code` is UNIQUE, so a bin code can only ever be redeemed once.
    await db.execute('''
      CREATE TABLE transactions (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        kind       TEXT NOT NULL,
        amount     INTEGER NOT NULL,
        items      INTEGER,
        code       TEXT UNIQUE,
        note       TEXT,
        created_at INTEGER NOT NULL
      )''');
    // kind: 'claim' | 'coupon' | 'bonus'   amount: + earned, - spent

    await db.execute(
        'CREATE INDEX idx_transactions_user ON transactions(user_id)');

    await db.execute('''
      CREATE TABLE coupons (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        cost       INTEGER NOT NULL,
        code       TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )''');

    // Key/value store: logged-in user, failed-attempt counter, lockout time.
    await db.execute('''
      CREATE TABLE kv (
        name  TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');

    await _createUsedCodes(db);
  }

  /// v1 -> v2: remember every redeemed bin code independently of accounts.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createUsedCodes(db);
      await db.execute('''
        INSERT OR IGNORE INTO used_codes (code, used_at)
        SELECT code, created_at FROM transactions WHERE code IS NOT NULL''');
    }
  }

  /// Bin codes that were already redeemed. NOT linked to users, so deleting
  /// an account can never make an old code redeemable again.
  Future<void> _createUsedCodes(Database db) => db.execute('''
    CREATE TABLE used_codes (
      code    TEXT PRIMARY KEY,
      used_at INTEGER NOT NULL
    )''');
}
