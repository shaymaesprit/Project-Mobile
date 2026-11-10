/// StudyMate — SQLite local cache.
///
/// Provides offline-first access to the five core entities:
///   courses, tasks, notes, flashcard_decks, flashcards, evaluations.
///
/// Usage pattern (cache-first):
///   1. Read from SQLite immediately → show data to user.
///   2. Fetch from API in background → upsert into SQLite → notify.
///
/// All public methods are safe to call from any isolate because sqflite
/// serialises writes internally.

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/study_models.dart';

/// Current schema version — bump when adding/changing tables.
const int _kDbVersion = 1;
const String _kDbName = 'studymate_cache.db';

// ─── Table names ────────────────────────────────────────────────────────────
const String _tCourses = 'courses';
const String _tTasks = 'tasks';
const String _tNotes = 'notes';
const String _tDecks = 'flashcard_decks';
const String _tFlashcards = 'flashcards';
const String _tEvaluations = 'evaluations';

/// Singleton SQLite cache for StudyMate.
class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), _kDbName);
    return openDatabase(
      dbPath,
      version: _kDbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tCourses (
        id        TEXT PRIMARY KEY,
        title     TEXT NOT NULL,
        code      TEXT,
        professor TEXT,
        room      TEXT,
        weekday   INTEGER,
        start_time TEXT,
        end_time  TEXT,
        synced_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tTasks (
        id           TEXT PRIMARY KEY,
        title        TEXT NOT NULL,
        description  TEXT,
        priority     TEXT NOT NULL DEFAULT 'medium',
        deadline     TEXT,
        course_id    TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        synced_at    TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tNotes (
        id         TEXT PRIMARY KEY,
        title      TEXT NOT NULL,
        content    TEXT NOT NULL DEFAULT '',
        course_id  TEXT,
        updated_at TEXT,
        synced_at  TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tDecks (
        id          TEXT PRIMARY KEY,
        title       TEXT NOT NULL,
        description TEXT,
        course_id   TEXT,
        source      TEXT NOT NULL DEFAULT 'manual',
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL,
        synced_at   TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tFlashcards (
        id           TEXT PRIMARY KEY,
        deck_id      TEXT,
        course_id    TEXT,
        question     TEXT NOT NULL,
        answer       TEXT NOT NULL,
        due_at       TEXT,
        repetitions  INTEGER NOT NULL DEFAULT 0,
        interval_days INTEGER NOT NULL DEFAULT 0,
        ease_factor  REAL NOT NULL DEFAULT 2.5,
        synced_at    TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tEvaluations (
        id               TEXT PRIMARY KEY,
        title            TEXT NOT NULL,
        evaluation_type  TEXT NOT NULL DEFAULT 'other',
        course_id        TEXT,
        scheduled_at     TEXT,
        score            REAL,
        max_score        REAL,
        notes            TEXT,
        created_at       TEXT NOT NULL,
        updated_at       TEXT NOT NULL,
        synced_at        TEXT NOT NULL
      )
    ''');

    // Useful indices
    await db.execute('CREATE INDEX idx_tasks_course ON $_tTasks (course_id)');
    await db.execute('CREATE INDEX idx_notes_course ON $_tNotes (course_id)');
    await db.execute('CREATE INDEX idx_cards_deck ON $_tFlashcards (deck_id)');
    await db.execute(
      'CREATE INDEX idx_evals_course ON $_tEvaluations (course_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here, keyed by oldVersion → newVersion.
    // Example: if (oldVersion < 2) { await db.execute('ALTER TABLE ...'); }
  }

  /// Wipe all cached data (call on sign-out).
  Future<void> clearAll() async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final table in [
        _tCourses,
        _tTasks,
        _tNotes,
        _tDecks,
        _tFlashcards,
        _tEvaluations,
      ]) {
        await txn.delete(table);
      }
    });
  }

  /// Close and release (call on app exit if needed).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _now => DateTime.now().toUtc().toIso8601String();

  /// Upsert a single row (INSERT OR REPLACE).
  Future<void> _upsert(
    String table,
    Map<String, dynamic> row,
  ) async {
    final db = await _database;
    await db.insert(
      table,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Upsert many rows in a single transaction.
  Future<void> _upsertAll(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;
    final db = await _database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(
          table,
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COURSES
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _courseToRow(StudyCourse c) => {
        'id': c.id,
        'title': c.title,
        'code': c.code,
        'professor': c.professor,
        'room': c.room,
        'weekday': c.weekday,
        'start_time': c.startTime,
        'end_time': c.endTime,
        'synced_at': _now,
      };

  StudyCourse _rowToCourse(Map<String, dynamic> r) => StudyCourse(
        id: r['id'] as String,
        title: r['title'] as String,
        code: r['code'] as String?,
        professor: r['professor'] as String?,
        room: r['room'] as String?,
        weekday: r['weekday'] as int?,
        startTime: r['start_time'] as String?,
        endTime: r['end_time'] as String?,
      );

  Future<List<StudyCourse>> getCourses() async {
    final db = await _database;
    final rows = await db.query(_tCourses, orderBy: 'title ASC');
    return rows.map(_rowToCourse).toList();
  }

  Future<void> upsertCourse(StudyCourse course) =>
      _upsert(_tCourses, _courseToRow(course));

  Future<void> upsertCourses(List<StudyCourse> courses) =>
      _upsertAll(_tCourses, courses.map(_courseToRow).toList());

  Future<void> deleteCourse(String id) async {
    final db = await _database;
    await db.delete(_tCourses, where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TASKS
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _taskToRow(StudyTask t) => {
        'id': t.id,
        'title': t.title,
        'description': t.description,
        'priority': t.priority,
        'deadline': t.deadline?.toUtc().toIso8601String(),
        'course_id': t.courseId,
        'is_completed': t.isCompleted ? 1 : 0,
        'synced_at': _now,
      };

  StudyTask _rowToTask(Map<String, dynamic> r) => StudyTask(
        id: r['id'] as String,
        title: r['title'] as String,
        description: r['description'] as String?,
        priority: r['priority'] as String? ?? 'medium',
        deadline: r['deadline'] == null
            ? null
            : DateTime.parse(r['deadline'] as String).toLocal(),
        courseId: r['course_id'] as String?,
        isCompleted: (r['is_completed'] as int? ?? 0) == 1,
      );

  Future<List<StudyTask>> getTasks() async {
    final db = await _database;
    final rows = await db.query(
      _tTasks,
      orderBy: 'is_completed ASC, deadline ASC, title ASC',
    );
    return rows.map(_rowToTask).toList();
  }

  Future<void> upsertTask(StudyTask task) =>
      _upsert(_tTasks, _taskToRow(task));

  Future<void> upsertTasks(List<StudyTask> tasks) =>
      _upsertAll(_tTasks, tasks.map(_taskToRow).toList());

  Future<void> deleteTask(String id) async {
    final db = await _database;
    await db.delete(_tTasks, where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTES
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _noteToRow(StudyNote n) => {
        'id': n.id,
        'title': n.title,
        'content': n.content,
        'course_id': n.courseId,
        'updated_at': n.updatedAt?.toUtc().toIso8601String(),
        'synced_at': _now,
      };

  StudyNote _rowToNote(Map<String, dynamic> r) => StudyNote(
        id: r['id'] as String,
        title: r['title'] as String,
        content: r['content'] as String? ?? '',
        courseId: r['course_id'] as String?,
        updatedAt: r['updated_at'] == null
            ? null
            : DateTime.parse(r['updated_at'] as String).toLocal(),
      );

  Future<List<StudyNote>> getNotes() async {
    final db = await _database;
    final rows = await db.query(
      _tNotes,
      orderBy: 'updated_at DESC, title ASC',
    );
    return rows.map(_rowToNote).toList();
  }

  Future<void> upsertNote(StudyNote note) =>
      _upsert(_tNotes, _noteToRow(note));

  Future<void> upsertNotes(List<StudyNote> notes) =>
      _upsertAll(_tNotes, notes.map(_noteToRow).toList());

  Future<void> deleteNote(String id) async {
    final db = await _database;
    await db.delete(_tNotes, where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FLASHCARD DECKS
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _deckToRow(StudyFlashcardDeck d) => {
        'id': d.id,
        'title': d.title,
        'description': d.description,
        'course_id': d.courseId,
        'source': d.source,
        'created_at': d.createdAt.toUtc().toIso8601String(),
        'updated_at': d.updatedAt.toUtc().toIso8601String(),
        'synced_at': _now,
      };

  StudyFlashcardDeck _rowToDeck(Map<String, dynamic> r) => StudyFlashcardDeck(
        id: r['id'] as String,
        title: r['title'] as String,
        description: r['description'] as String?,
        courseId: r['course_id'] as String?,
        source: r['source'] as String? ?? 'manual',
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(r['updated_at'] as String).toLocal(),
      );

  Future<List<StudyFlashcardDeck>> getFlashcardDecks() async {
    final db = await _database;
    final rows = await db.query(_tDecks, orderBy: 'updated_at DESC');
    return rows.map(_rowToDeck).toList();
  }

  Future<void> upsertDeck(StudyFlashcardDeck deck) =>
      _upsert(_tDecks, _deckToRow(deck));

  Future<void> upsertDecks(List<StudyFlashcardDeck> decks) =>
      _upsertAll(_tDecks, decks.map(_deckToRow).toList());

  Future<void> deleteDeck(String id) async {
    final db = await _database;
    await db.delete(_tDecks, where: 'id = ?', whereArgs: [id]);
    // Cascade delete flashcards in that deck
    await db.delete(_tFlashcards, where: 'deck_id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FLASHCARDS
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _flashcardToRow(StudyFlashcard f) => {
        'id': f.id,
        'deck_id': f.deckId,
        'course_id': f.courseId,
        'question': f.question,
        'answer': f.answer,
        'due_at': f.dueAt?.toUtc().toIso8601String(),
        'repetitions': f.repetitions,
        'interval_days': f.intervalDays,
        'ease_factor': f.easeFactor,
        'synced_at': _now,
      };

  StudyFlashcard _rowToFlashcard(Map<String, dynamic> r) => StudyFlashcard(
        id: r['id'] as String,
        deckId: r['deck_id'] as String?,
        courseId: r['course_id'] as String?,
        question: r['question'] as String,
        answer: r['answer'] as String,
        dueAt: r['due_at'] == null
            ? null
            : DateTime.parse(r['due_at'] as String).toLocal(),
        repetitions: r['repetitions'] as int? ?? 0,
        intervalDays: r['interval_days'] as int? ?? 0,
        easeFactor: (r['ease_factor'] as num?)?.toDouble() ?? 2.5,
      );

  Future<List<StudyFlashcard>> getFlashcards(String deckId) async {
    final db = await _database;
    final rows = await db.query(
      _tFlashcards,
      where: 'deck_id = ?',
      whereArgs: [deckId],
      orderBy: 'due_at ASC',
    );
    return rows.map(_rowToFlashcard).toList();
  }

  Future<void> upsertFlashcard(StudyFlashcard card) =>
      _upsert(_tFlashcards, _flashcardToRow(card));

  Future<void> upsertFlashcards(List<StudyFlashcard> cards) =>
      _upsertAll(_tFlashcards, cards.map(_flashcardToRow).toList());

  Future<void> deleteFlashcard(String id) async {
    final db = await _database;
    await db.delete(_tFlashcards, where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EVALUATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _evalToRow(StudyEvaluation e) => {
        'id': e.id,
        'title': e.title,
        'evaluation_type': e.evaluationType,
        'course_id': e.courseId,
        'scheduled_at': e.scheduledAt?.toUtc().toIso8601String(),
        'score': e.score,
        'max_score': e.maxScore,
        'notes': e.notes,
        'created_at': e.createdAt.toUtc().toIso8601String(),
        'updated_at': e.updatedAt.toUtc().toIso8601String(),
        'synced_at': _now,
      };

  StudyEvaluation _rowToEval(Map<String, dynamic> r) => StudyEvaluation(
        id: r['id'] as String,
        title: r['title'] as String,
        evaluationType: r['evaluation_type'] as String? ?? 'other',
        courseId: r['course_id'] as String?,
        scheduledAt: r['scheduled_at'] == null
            ? null
            : DateTime.parse(r['scheduled_at'] as String).toLocal(),
        score: (r['score'] as num?)?.toDouble(),
        maxScore: (r['max_score'] as num?)?.toDouble(),
        notes: r['notes'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(r['updated_at'] as String).toLocal(),
      );

  Future<List<StudyEvaluation>> getEvaluations() async {
    final db = await _database;
    final rows = await db.query(
      _tEvaluations,
      orderBy: 'scheduled_at DESC, created_at DESC',
    );
    return rows.map(_rowToEval).toList();
  }

  Future<void> upsertEvaluation(StudyEvaluation eval) =>
      _upsert(_tEvaluations, _evalToRow(eval));

  Future<void> upsertEvaluations(List<StudyEvaluation> evals) =>
      _upsertAll(_tEvaluations, evals.map(_evalToRow).toList());

  Future<void> deleteEvaluation(String id) async {
    final db = await _database;
    await db.delete(_tEvaluations, where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATS (bonus — utilisé dans le dashboard)
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns quick stats useful for the offline dashboard.
  Future<LocalCacheStats> getStats() async {
    final db = await _database;
    final courseCount =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $_tCourses')) ?? 0;
    final taskCount =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $_tTasks')) ?? 0;
    final completedCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $_tTasks WHERE is_completed = 1',
          ),
        ) ??
        0;
    final noteCount =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $_tNotes')) ?? 0;
    final deckCount =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $_tDecks')) ?? 0;
    final cardCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_tFlashcards'),
        ) ??
        0;
    final evalCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_tEvaluations'),
        ) ??
        0;

    return LocalCacheStats(
      courseCount: courseCount,
      taskCount: taskCount,
      completedTaskCount: completedCount,
      noteCount: noteCount,
      deckCount: deckCount,
      flashcardCount: cardCount,
      evaluationCount: evalCount,
    );
  }
}

/// Lightweight stats derived from the local SQLite cache.
class LocalCacheStats {
  const LocalCacheStats({
    required this.courseCount,
    required this.taskCount,
    required this.completedTaskCount,
    required this.noteCount,
    required this.deckCount,
    required this.flashcardCount,
    required this.evaluationCount,
  });

  final int courseCount;
  final int taskCount;
  final int completedTaskCount;
  final int noteCount;
  final int deckCount;
  final int flashcardCount;
  final int evaluationCount;

  int get pendingTaskCount => taskCount - completedTaskCount;
}
