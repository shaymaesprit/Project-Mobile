import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Résultat d'un quiz terminé.
class QuizResult {
  const QuizResult({
    required this.title,
    required this.score,
    required this.total,
    required this.at,
  });

  final String title;
  final int score;
  final int total;
  final DateTime at;

  double get ratio => total == 0 ? 0 : score / total;
}

/// Mesure le temps passé dans l'application (au premier plan), jour par
/// jour et par compte, et garde l'historique des quiz. Tout reste sur le
/// téléphone (SQLite) : ce sont des statistiques personnelles.
class UsageTracker with WidgetsBindingObserver {
  UsageTracker._();

  static final UsageTracker instance = UsageTracker._();

  static const _dbName = 'studymate_usage.db';

  String? Function()? _uid;
  DateTime? _since;
  Timer? _ticker;
  Database? _db;
  Future<Database>? _opening;

  Future<Database> get _database {
    final existing = _db;
    if (existing != null) return Future.value(existing);
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), _dbName),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE usage (
            user_id TEXT NOT NULL,
            day     TEXT NOT NULL,
            seconds INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (user_id, day)
          )
        ''');
        await db.execute('''
          CREATE TABLE quiz_results (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            title   TEXT NOT NULL,
            score   INTEGER NOT NULL,
            total   INTEGER NOT NULL,
            at      INTEGER NOT NULL
          )
        ''');
      },
    );
    _db = db;
    return db;
  }

  /// À appeler une fois au démarrage.
  void start(String? Function() userIdProvider) {
    if (_uid != null) return;
    _uid = userIdProvider;
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      unawaited(_flush());
      _ticker?.cancel();
      _since = null;
    }
  }

  void _resume() {
    _since = DateTime.now();
    _ticker?.cancel();
    // Sauvegarde régulière : rien n'est perdu si l'app est tuée.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _flush());
  }

  Future<void> _flush() async {
    final since = _since;
    final uid = _uid?.call();
    if (since == null) return;
    final now = DateTime.now();
    _since = now;
    if (uid == null) return;
    final seconds = now.difference(since).inSeconds;
    if (seconds <= 0 || seconds > 3600) return; // horloge incohérente : ignoré
    try {
      final db = await _database;
      await db.rawInsert(
        'INSERT INTO usage (user_id, day, seconds) VALUES (?, ?, ?) '
        'ON CONFLICT(user_id, day) DO UPDATE SET seconds = seconds + excluded.seconds',
        [uid, _key(since), seconds],
      );
    } catch (_) {
      // Statistique de confort : jamais bloquant.
    }
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String _key(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Secondes passées par jour sur les [days] derniers jours (du plus ancien
  /// au plus récent), aujourd'hui compris.
  Future<List<({DateTime day, int seconds})>> lastDays(int days) async {
    await _flush();
    final uid = _uid?.call();
    final today = _today();
    final keys = [
      for (var i = days - 1; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    if (uid == null) return [for (final d in keys) (day: d, seconds: 0)];
    final db = await _database;
    final rows = await db.query(
      'usage',
      where: 'user_id = ? AND day >= ?',
      whereArgs: [uid, _key(keys.first)],
    );
    final byDay = {for (final r in rows) r['day'] as String: r['seconds'] as int};
    return [for (final d in keys) (day: d, seconds: byDay[_key(d)] ?? 0)];
  }

  /// Jours consécutifs (jusqu'à aujourd'hui) avec au moins 1 min d'utilisation.
  Future<int> streak() async {
    final days = await lastDays(60);
    var count = 0;
    for (final entry in days.reversed) {
      if (entry.seconds >= 60) {
        count++;
      } else if (count > 0 || entry.day != _today()) {
        break;
      }
    }
    return count;
  }

  Future<void> saveQuiz(QuizResult result) async {
    final uid = _uid?.call();
    if (uid == null) return;
    final db = await _database;
    await db.insert('quiz_results', {
      'user_id': uid,
      'title': result.title,
      'score': result.score,
      'total': result.total,
      'at': result.at.millisecondsSinceEpoch,
    });
  }

  Future<List<QuizResult>> quizHistory({int limit = 20}) async {
    final uid = _uid?.call();
    if (uid == null) return const [];
    final db = await _database;
    final rows = await db.query(
      'quiz_results',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'at DESC',
      limit: limit,
    );
    return [
      for (final r in rows)
        QuizResult(
          title: r['title'] as String,
          score: r['score'] as int,
          total: r['total'] as int,
          at: DateTime.fromMillisecondsSinceEpoch(r['at'] as int),
        ),
    ];
  }
}
