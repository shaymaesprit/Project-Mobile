import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/event_models.dart';

/// Base SQLite locale de la gestion « Événements & Notifications ».
///
/// Trois tables : `events`, `calendar_items`, `notifications`.
/// Chaque ligne porte le `user_id` (uid Firebase) : toutes les requêtes sont
/// filtrées dessus et la base est vidée à la déconnexion, pour que deux
/// étudiants sur le même téléphone ne voient jamais les données de l'autre.
///
/// Les dates sont stockées en millisecondes UTC (INTEGER) : cela permet des
/// comparaisons `WHERE` / `ORDER BY` fiables et des index efficaces.
class EventsLocalDb {
  EventsLocalDb._();

  static final EventsLocalDb instance = EventsLocalDb._();

  static const _dbName = 'studymate_events.db';
  static const _dbVersion = 2;

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get _database {
    final existing = _db;
    if (existing != null) return Future.value(existing);
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createTables(db);
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2 : ajout des index (le schéma des tables est inchangé).
        if (oldVersion < 2) {
          await _createIndexes(db);
        }
      },
    );
    _db = db;
    return db;
  }

  // ---------------------------------------------------------------------
  // Création du schéma
  // ---------------------------------------------------------------------
  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id               TEXT NOT NULL,
        user_id          TEXT NOT NULL,
        title            TEXT NOT NULL,
        event_type       TEXT NOT NULL,
        starts_at        INTEGER NOT NULL,
        ends_at          INTEGER,
        description      TEXT,
        course_id        TEXT,
        location         TEXT,
        latitude         REAL,
        longitude        REAL,
        status           TEXT NOT NULL DEFAULT 'planned',
        reminder_offsets TEXT NOT NULL DEFAULT '[]',
        synced_at        INTEGER NOT NULL,
        PRIMARY KEY (user_id, id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS calendar_items (
        id         TEXT NOT NULL,
        user_id    TEXT NOT NULL,
        kind       TEXT NOT NULL,
        title      TEXT NOT NULL,
        starts_at  INTEGER NOT NULL,
        ends_at    INTEGER,
        category   TEXT NOT NULL,
        status     TEXT,
        location   TEXT,
        completed  INTEGER,
        synced_at  INTEGER NOT NULL,
        PRIMARY KEY (user_id, kind, id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id                TEXT NOT NULL,
        user_id           TEXT NOT NULL,
        notification_type TEXT NOT NULL,
        title             TEXT NOT NULL,
        body              TEXT NOT NULL,
        created_at        INTEGER NOT NULL,
        payload           TEXT NOT NULL DEFAULT '{}',
        read_at           INTEGER,
        synced_at         INTEGER NOT NULL,
        PRIMARY KEY (user_id, id)
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_user_start '
        'ON events (user_id, starts_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_user_type '
        'ON events (user_id, event_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_items_user_start '
        'ON calendar_items (user_id, starts_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_items_user_end '
        'ON calendar_items (user_id, ends_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notif_user_created '
        'ON notifications (user_id, created_at DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notif_user_read '
        'ON notifications (user_id, read_at)');
  }

  // ---------------------------------------------------------------------
  // Conversions
  // ---------------------------------------------------------------------
  static int _ms(DateTime value) => value.toUtc().millisecondsSinceEpoch;

  static DateTime _date(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();

  static DateTime? _optDate(Object? ms) => ms == null ? null : _date(ms as int);

  // ---------------------------------------------------------------------
  // calendar_items
  // ---------------------------------------------------------------------

  /// Lecture d'une plage : tout ce qui chevauche [from, to), trié par début.
  Future<List<CalendarItem>> getCalendarItems(
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'calendar_items',
      where: 'user_id = ? AND starts_at < ? '
          'AND COALESCE(ends_at, starts_at) >= ?',
      whereArgs: [userId, _ms(to), _ms(from)],
      orderBy: 'starts_at ASC, title ASC',
    );
    return rows.map(_itemFromRow).toList();
  }

  /// Remplace le contenu local de la plage par le résultat de l'API
  /// (insertion + mise à jour + suppression des lignes disparues).
  Future<void> replaceCalendarRange(
    String userId,
    DateTime from,
    DateTime to,
    List<CalendarItem> items,
  ) async {
    final db = await _database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete(
        'calendar_items',
        where: 'user_id = ? AND starts_at < ? '
            'AND COALESCE(ends_at, starts_at) >= ?',
        whereArgs: [userId, _ms(to), _ms(from)],
      );
      final batch = txn.batch();
      for (final item in items) {
        batch.insert(
          'calendar_items',
          {
            'id': item.id,
            'user_id': userId,
            'kind': item.kind,
            'title': item.title,
            'starts_at': _ms(item.startsAt),
            'ends_at': item.endsAt == null ? null : _ms(item.endsAt!),
            'category': item.category,
            'status': item.status,
            'location': item.location,
            'completed':
                item.completed == null ? null : (item.completed! ? 1 : 0),
            'synced_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Recherche plein texte simple (LIKE) sur le titre, le lieu et la
  /// catégorie — fonctionne hors ligne.
  Future<List<CalendarItem>> searchCalendarItems(
    String userId,
    String query, {
    int limit = 50,
  }) async {
    final db = await _database;
    final like = '%${query.trim().replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final rows = await db.query(
      'calendar_items',
      where: "user_id = ? AND (title LIKE ? ESCAPE '\\' "
          "OR COALESCE(location, '') LIKE ? ESCAPE '\\' "
          "OR category LIKE ? ESCAPE '\\')",
      whereArgs: [userId, like, like, like],
      orderBy: 'starts_at DESC',
      limit: limit,
    );
    return rows.map(_itemFromRow).toList();
  }

  /// Statistiques calculées en SQL (GROUP BY) : nombre d'éléments par
  /// catégorie à partir de [from].
  Future<Map<String, int>> countByCategory(
    String userId,
    DateTime from,
  ) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT category, COUNT(*) AS total FROM calendar_items '
      'WHERE user_id = ? AND starts_at >= ? '
      'GROUP BY category ORDER BY total DESC',
      [userId, _ms(from)],
    );
    return {
      for (final row in rows) row['category'] as String: row['total'] as int,
    };
  }

  /// Date de la dernière synchronisation réussie (ou null si jamais).
  Future<DateTime?> lastSyncedAt(String userId) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT MAX(synced_at) AS last FROM ('
      'SELECT synced_at FROM calendar_items WHERE user_id = ? '
      'UNION ALL SELECT synced_at FROM notifications WHERE user_id = ? '
      'UNION ALL SELECT synced_at FROM events WHERE user_id = ?)',
      [userId, userId, userId],
    );
    final value = rows.isEmpty ? null : rows.first['last'];
    return value == null ? null : _date(value as int);
  }

  CalendarItem _itemFromRow(Map<String, Object?> row) => CalendarItem(
        kind: row['kind'] as String,
        id: row['id'] as String,
        title: row['title'] as String,
        startsAt: _date(row['starts_at'] as int),
        endsAt: _optDate(row['ends_at']),
        category: row['category'] as String,
        status: row['status'] as String?,
        location: row['location'] as String?,
        completed: row['completed'] == null ? null : row['completed'] == 1,
      );

  // ---------------------------------------------------------------------
  // events
  // ---------------------------------------------------------------------
  Future<void> upsertEvent(String userId, StudyEvent event) =>
      upsertEvents(userId, [event]);

  Future<void> upsertEvents(String userId, List<StudyEvent> events) async {
    final db = await _database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final event in events) {
      batch.insert(
        'events',
        {
          'id': event.id,
          'user_id': userId,
          'title': event.title,
          'event_type': event.eventType,
          'starts_at': _ms(event.startsAt),
          'ends_at': event.endsAt == null ? null : _ms(event.endsAt!),
          'description': event.description,
          'course_id': event.courseId,
          'location': event.location,
          'latitude': event.latitude,
          'longitude': event.longitude,
          'status': event.status,
          'reminder_offsets': jsonEncode(event.reminderOffsets),
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<StudyEvent?> getEvent(String userId, String id) async {
    final db = await _database;
    final rows = await db.query(
      'events',
      where: 'user_id = ? AND id = ?',
      whereArgs: [userId, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return StudyEvent(
      id: row['id'] as String,
      title: row['title'] as String,
      eventType: row['event_type'] as String,
      startsAt: _date(row['starts_at'] as int),
      endsAt: _optDate(row['ends_at']),
      description: row['description'] as String?,
      courseId: row['course_id'] as String?,
      location: row['location'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      status: (row['status'] as String?) ?? 'planned',
      reminderOffsets: (jsonDecode(row['reminder_offsets'] as String)
              as List<dynamic>)
          .map((value) => value as int)
          .toList(),
    );
  }

  /// Supprime un événement et ses lignes dérivées du calendrier.
  Future<void> deleteEvent(String userId, String id) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(
        'events',
        where: 'user_id = ? AND id = ?',
        whereArgs: [userId, id],
      );
      await txn.delete(
        'calendar_items',
        where: 'user_id = ? AND kind = ? AND id = ?',
        whereArgs: [userId, 'event', id],
      );
    });
  }

  // ---------------------------------------------------------------------
  // notifications
  // ---------------------------------------------------------------------
  Future<List<AppNotification>> getNotifications(
    String userId, {
    bool unreadOnly = false,
    String? type,
    int limit = 50,
  }) async {
    final db = await _database;
    final where = StringBuffer('user_id = ?');
    final args = <Object?>[userId];
    if (unreadOnly) where.write(' AND read_at IS NULL');
    if (type != null) {
      where.write(' AND notification_type = ?');
      args.add(type);
    }
    final rows = await db.query(
      'notifications',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows
        .map((row) => AppNotification(
              id: row['id'] as String,
              type: row['notification_type'] as String,
              title: row['title'] as String,
              body: row['body'] as String,
              createdAt: _date(row['created_at'] as int),
              payload: (jsonDecode(row['payload'] as String)
                  as Map<String, dynamic>),
              readAt: _optDate(row['read_at']),
            ))
        .toList();
  }

  Future<int> unreadCount(String userId) async {
    final db = await _database;
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM notifications '
          'WHERE user_id = ? AND read_at IS NULL',
          [userId],
        )) ??
        0;
  }

  /// Insère / met à jour les notifications reçues de l'API. Quand la liste
  /// n'est pas filtrée ([replaceAll]), les lignes absentes sont supprimées.
  Future<void> upsertNotifications(
    String userId,
    List<AppNotification> notifications, {
    bool replaceAll = false,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      if (replaceAll) {
        await txn.delete(
          'notifications',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }
      final batch = txn.batch();
      for (final n in notifications) {
        batch.insert(
          'notifications',
          {
            'id': n.id,
            'user_id': userId,
            'notification_type': n.type,
            'title': n.title,
            'body': n.body,
            'created_at': _ms(n.createdAt),
            'payload': jsonEncode(n.payload),
            'read_at': n.readAt == null ? null : _ms(n.readAt!),
            'synced_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> markNotificationRead(String userId, String id) async {
    final db = await _database;
    await db.update(
      'notifications',
      {'read_at': DateTime.now().toUtc().millisecondsSinceEpoch},
      where: 'user_id = ? AND id = ? AND read_at IS NULL',
      whereArgs: [userId, id],
    );
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final db = await _database;
    await db.update(
      'notifications',
      {'read_at': DateTime.now().toUtc().millisecondsSinceEpoch},
      where: 'user_id = ? AND read_at IS NULL',
      whereArgs: [userId],
    );
  }

  Future<void> deleteNotification(String userId, String id) async {
    final db = await _database;
    await db.delete(
      'notifications',
      where: 'user_id = ? AND id = ?',
      whereArgs: [userId, id],
    );
  }

  // ---------------------------------------------------------------------
  // Sécurité : purge
  // ---------------------------------------------------------------------

  /// Vide les trois tables (appelé à la déconnexion).
  Future<void> clearAll() async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('events');
      await txn.delete('calendar_items');
      await txn.delete('notifications');
    });
  }

  /// Supprime les lignes de tous les autres utilisateurs (garde-fou si la
  /// déconnexion n'a pas pu purger la base, ex. fermeture brutale).
  Future<void> purgeOtherUsers(String userId) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final table in const ['events', 'calendar_items', 'notifications']) {
        await txn.delete(table, where: 'user_id <> ?', whereArgs: [userId]);
      }
    });
  }
}
