import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class InsuranceDb {
  static Database? _db;

  static const _dbName = 'insurance.db';
  static const _dbVersion = 9;
  static const _notifTable = 'user_notifications';

  static Future<bool> _columnExists(
    Database db,
    String table,
    String column,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.any((row) => row['name'] == column);
  }

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  // -----------------------
  // Schema
  // -----------------------
  static Future<void> _createNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_notifTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        server_id TEXT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        target_type TEXT,
        target_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_notif_user_server
      ON $_notifTable(user_id, server_id)
    ''');
  }

  static Future<void> _ensureNotificationColumns(Database db) async {
    final hasTargetType = await _columnExists(db, _notifTable, 'target_type');
    if (!hasTargetType) {
      await db.execute("ALTER TABLE $_notifTable ADD COLUMN target_type TEXT");
    }

    final hasTargetId = await _columnExists(db, _notifTable, 'target_id');
    if (!hasTargetId) {
      await db.execute("ALTER TABLE $_notifTable ADD COLUMN target_id INTEGER");
    }

    final hasServerId = await _columnExists(db, _notifTable, 'server_id');
    if (!hasServerId) {
      await db.execute("ALTER TABLE $_notifTable ADD COLUMN server_id TEXT");
    }

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_notif_user_server
      ON $_notifTable(user_id, server_id)
    ''');
  }

  // -----------------------
  // Notifications (Local)
  // -----------------------
  static Future<int> insertNotification(Map<String, Object?> row) async {
    final db = await database;

    final clean = Map<String, Object?>.from(row);
    clean['created_at'] ??= DateTime.now().toIso8601String();
    clean['is_read'] ??= 0;

    // normalize message -> body
    if (clean.containsKey('message') && !clean.containsKey('body')) {
      clean['body'] = clean['message'];
      clean.remove('message');
    }

    if (clean.containsKey('target_type') && clean['target_type'] != null) {
      clean['target_type'] = clean['target_type']
          .toString()
          .trim()
          .toUpperCase();
    }
    if (clean.containsKey('target_id')) {
      clean['target_id'] = _asInt(clean['target_id']);
    }

    return db.insert(_notifTable, clean);
  }

  static Future<List<Map<String, Object?>>> fetchNotificationsForUser(
    String userId,
  ) async {
    final db = await database;
    return db.query(
      _notifTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
  }

  static Future<int> markNotificationRead(int id) async {
    final db = await database;
    return db.update(
      _notifTable,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> markAllNotificationsReadForUser(String userId) async {
    final db = await database;
    return db.rawUpdate(
      'UPDATE $_notifTable SET is_read = 1 WHERE user_id = ?',
      [userId],
    );
  }

  static Future<int> clearNotificationsForUser(String userId) async {
    final db = await database;
    return db.delete(_notifTable, where: 'user_id = ?', whereArgs: [userId]);
  }

  // -----------------------
  // Server sync helper
  // -----------------------
  static Future<void> upsertNotificationsForUser(
    String userId,
    List<dynamic> serverList,
  ) async {
    final db = await database;

    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final n in serverList) {
        if (n is! Map) continue;
        final m = Map<String, dynamic>.from(n);

        String serverId = (m['id'] ?? m['_id'] ?? m['notificationId'] ?? '')
            .toString()
            .trim();

        final title = (m['title'] ?? m['type'] ?? 'Notification').toString();
        final body = (m['body'] ?? m['message'] ?? m['status'] ?? '')
            .toString();
        final createdAt =
            (m['createdAt'] ??
                    m['timestamp'] ??
                    DateTime.now().toIso8601String())
                .toString();

        if (serverId.isEmpty) {
          serverId = '$title|$body|$createdAt';
        }

        batch.insert(_notifTable, {
          'user_id': userId,
          'server_id': serverId,
          'title': title,
          'body': body,
          'created_at': createdAt,
          'is_read': 0,
          'target_type': (m['targetType'] ?? m['target_type'])?.toString(),
          'target_id': _asInt(m['targetId'] ?? m['target_id']),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      await batch.commit(noResult: true);
    });
  }

  // -----------------------
  // Debug helper
  // -----------------------
  static Future<void> clearAllLocalDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await deleteDatabase(path);
    _db = null;
  }

  // -----------------------
  // DB getter (ONLY ONE)
  // -----------------------
  static Future<Database> get database async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    Future<Database> open() async {
      return openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, version) async {
          await _createNotificationsTable(db);
          await _ensureNotificationColumns(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _createNotificationsTable(db);
          await _ensureNotificationColumns(db);
          try {
            await db.execute('DROP TABLE IF EXISTS insurance_uploads');
          } catch (_) {}
        },
      );
    }

    try {
      _db = await open();
    } catch (_) {
      await deleteDatabase(path);
      _db = await open();
    }

    return _db!;
  }
}
