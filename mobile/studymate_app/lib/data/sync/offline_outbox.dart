import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Préfixe des identifiants créés hors ligne, remplacés à la synchronisation.
const localIdPrefix = 'local-';

bool isLocalId(String id) => id.startsWith(localIdPrefix);

String newLocalId() => '$localIdPrefix${DateTime.now().microsecondsSinceEpoch}';

enum OutboxOp { create, update, delete }

/// Une modification faite sur le téléphone, en attente d'envoi au serveur.
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.entity,
    required this.op,
    required this.entityId,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });

  final int id;
  final String entity; // course | task | note | event
  final OutboxOp op;
  final String entityId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  factory OutboxEntry._fromRow(Map<String, Object?> row) => OutboxEntry(
        id: row['id'] as int,
        entity: row['entity'] as String,
        op: OutboxOp.values.byName(row['op'] as String),
        entityId: row['entity_id'] as String,
        payload: Map<String, dynamic>.from(
          jsonDecode(row['payload'] as String) as Map,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        attempts: row['attempts'] as int,
        lastError: row['last_error'] as String?,
      );
}

/// File d'attente persistante (SQLite) des créations / modifications /
/// suppressions faites hors ligne. Chaque ligne appartient à un utilisateur.
///
/// Fusion à l'enregistrement, pour n'envoyer que l'essentiel :
/// * créer puis modifier   → une seule création (avec les dernières valeurs) ;
/// * modifier puis modifier → une seule modification ;
/// * créer puis supprimer  → rien à envoyer ;
/// * modifier puis supprimer → seulement la suppression.
class OfflineOutbox {
  OfflineOutbox._([this._path]);

  static final OfflineOutbox instance = OfflineOutbox._();

  /// Base en mémoire, isolée, pour les tests.
  @visibleForTesting
  factory OfflineOutbox.inMemory() => OfflineOutbox._(inMemoryDatabasePath);

  final String? _path;

  static const _dbName = 'studymate_outbox.db';
  static const _table = 'outbox';

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get _database {
    final existing = _db;
    if (existing != null) return Future.value(existing);
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    final db = await openDatabase(
      _path ?? p.join(await getDatabasesPath(), _dbName),
      version: 1,
      // En test, chaque file en mémoire est indépendante.
      singleInstance: _path == null,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_table (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     TEXT NOT NULL,
            entity      TEXT NOT NULL,
            op          TEXT NOT NULL,
            entity_id   TEXT NOT NULL,
            payload     TEXT NOT NULL,
            created_at  INTEGER NOT NULL,
            attempts    INTEGER NOT NULL DEFAULT 0,
            last_error  TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_outbox_user ON $_table (user_id, id)',
        );
      },
    );
    _db = db;
    return db;
  }

  /// Ajoute une opération (en la fusionnant avec celles déjà en attente).
  Future<void> enqueue({
    required String userId,
    required String entity,
    required OutboxOp op,
    required String entityId,
    Map<String, dynamic> payload = const {},
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      final pending = (await txn.query(
        _table,
        where: 'user_id = ? AND entity = ? AND entity_id = ?',
        whereArgs: [userId, entity, entityId],
        orderBy: 'id ASC',
      ))
          .map(OutboxEntry._fromRow)
          .toList();
      final pendingCreate =
          pending.where((e) => e.op == OutboxOp.create).firstOrNull;
      final pendingUpdate =
          pending.where((e) => e.op == OutboxOp.update).lastOrNull;

      switch (op) {
        case OutboxOp.create:
          await _insert(txn, userId, entity, op, entityId, payload);
        case OutboxOp.update:
          final target = pendingCreate ?? pendingUpdate;
          if (target != null) {
            await txn.update(
              _table,
              {'payload': jsonEncode({...target.payload, ...payload})},
              where: 'id = ?',
              whereArgs: [target.id],
            );
          } else {
            await _insert(txn, userId, entity, op, entityId, payload);
          }
        case OutboxOp.delete:
          await txn.delete(
            _table,
            where: 'user_id = ? AND entity = ? AND entity_id = ?',
            whereArgs: [userId, entity, entityId],
          );
          // Jamais envoyé au serveur : il n'y a rien à supprimer là-bas.
          if (pendingCreate == null && !isLocalId(entityId)) {
            await _insert(txn, userId, entity, op, entityId, payload);
          }
      }
    });
  }

  Future<void> _insert(
    Transaction txn,
    String userId,
    String entity,
    OutboxOp op,
    String entityId,
    Map<String, dynamic> payload,
  ) =>
      txn.insert(_table, {
        'user_id': userId,
        'entity': entity,
        'op': op.name,
        'entity_id': entityId,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

  Future<List<OutboxEntry>> pending(String userId, {String? entity}) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where: entity == null ? 'user_id = ?' : 'user_id = ? AND entity = ?',
      whereArgs: entity == null ? [userId] : [userId, entity],
      orderBy: 'id ASC',
    );
    return rows.map(OutboxEntry._fromRow).toList();
  }

  Future<int> count(String userId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM $_table WHERE user_id = ?',
      [userId],
    );
    return (result.first['n'] as int?) ?? 0;
  }

  Future<void> remove(int id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Termine une création envoyée avec [sentPayload]. Si l'étudiant a modifié
  /// l'élément pendant l'envoi (la ligne a changé), la ligne devient une
  /// modification à envoyer au lieu d'être supprimée : rien n'est perdu.
  Future<void> completeCreate(
    int id,
    Map<String, dynamic> sentPayload,
    String serverId,
  ) async {
    final db = await _database;
    await db.transaction((txn) async {
      final rows = await txn.query(_table, where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final current = rows.first['payload'] as String;
      if (current == jsonEncode(sentPayload)) {
        await txn.delete(_table, where: 'id = ?', whereArgs: [id]);
      } else {
        await txn.update(
          _table,
          {'op': OutboxOp.update.name, 'entity_id': serverId},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> markFailed(int id, String error) async {
    final db = await _database;
    await db.rawUpdate(
      'UPDATE $_table SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }

  /// Après une création réussie : remplace l'identifiant local par celui du
  /// serveur dans toutes les opérations en attente (y compris les références,
  /// ex. une tâche créée hors ligne dans un cours lui aussi créé hors ligne).
  Future<void> remapId(String userId, String localId, String serverId) async {
    final db = await _database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        _table,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      for (final row in rows) {
        final payload = row['payload'] as String;
        final updates = <String, Object?>{};
        if (row['entity_id'] == localId) updates['entity_id'] = serverId;
        if (payload.contains(localId)) {
          updates['payload'] = payload.replaceAll('"$localId"', '"$serverId"');
        }
        if (updates.isNotEmpty) {
          await txn.update(_table, updates, where: 'id = ?', whereArgs: [row['id']]);
        }
      }
    });
  }

  /// Sécurité : supprime les opérations d'autres comptes sur ce téléphone.
  Future<void> purgeOtherUsers(String userId) async {
    final db = await _database;
    await db.delete(_table, where: 'user_id != ?', whereArgs: [userId]);
  }

  Future<void> clearUser(String userId) async {
    final db = await _database;
    await db.delete(_table, where: 'user_id = ?', whereArgs: [userId]);
  }
}
