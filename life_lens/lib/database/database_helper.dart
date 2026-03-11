import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/life_event.dart';
import '../models/daily_summary.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'life_lens.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE life_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        duration_seconds INTEGER DEFAULT 0,
        data TEXT DEFAULT '{}'
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL UNIQUE,
        narrative TEXT,
        insights TEXT,
        recommendations TEXT,
        productivity_score INTEGER DEFAULT 0,
        wellbeing_score INTEGER DEFAULT 0,
        raw_stats TEXT DEFAULT '',
        generated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        app_name TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE location_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        address TEXT,
        place_name TEXT,
        timestamp INTEGER NOT NULL,
        duration_seconds INTEGER DEFAULT 0
      )
    ''');

    // Indexes for fast queries
    await db.execute('CREATE INDEX idx_events_timestamp ON life_events(timestamp)');
    await db.execute('CREATE INDEX idx_events_type ON life_events(type)');
    await db.execute('CREATE INDEX idx_sessions_date ON app_sessions(date)');
    await db.execute('CREATE INDEX idx_sessions_package ON app_sessions(package_name)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_events_timestamp ON life_events(timestamp)');
    }
  }

  // ── Life Events ──────────────────────────────────────────────────────────

  Future<int> insertEvent(LifeEvent event) async {
    final db = await database;
    return db.insert('life_events', event.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LifeEvent>> getEventsForDay(DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;

    final maps = await db.query(
      'life_events',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'timestamp ASC',
    );
    return maps.map(LifeEvent.fromMap).toList();
  }

  Future<List<LifeEvent>> getEventsForRange(DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query(
      'life_events',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC',
    );
    return maps.map(LifeEvent.fromMap).toList();
  }

  Future<List<LifeEvent>> getEventsByType(String type, DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;

    final maps = await db.query(
      'life_events',
      where: 'type = ? AND timestamp BETWEEN ? AND ?',
      whereArgs: [type, start, end],
      orderBy: 'timestamp ASC',
    );
    return maps.map(LifeEvent.fromMap).toList();
  }

  // ── App Sessions ──────────────────────────────────────────────────────────

  Future<void> insertAppSession({
    required String packageName,
    required String? appName,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final db = await database;
    final duration = endTime.difference(startTime).inSeconds;
    if (duration < 5) return; // ignore very short sessions

    await db.insert('app_sessions', {
      'package_name': packageName,
      'app_name': appName ?? packageName,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'duration_seconds': duration,
      'date': _dateKey(startTime),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, int>> getAppUsageForDay(DateTime day) async {
    final db = await database;
    final dateKey = _dateKey(day);

    final result = await db.rawQuery('''
      SELECT package_name, app_name, SUM(duration_seconds) as total_seconds
      FROM app_sessions
      WHERE date = ?
      GROUP BY package_name
      ORDER BY total_seconds DESC
    ''', [dateKey]);

    final usage = <String, int>{};
    for (final row in result) {
      final name = (row['app_name'] as String?) ?? (row['package_name'] as String);
      usage[name] = (row['total_seconds'] as int? ?? 0) ~/ 60;
    }
    return usage;
  }

  Future<int> getTotalScreenTimeForDay(DateTime day) async {
    final db = await database;
    final dateKey = _dateKey(day);

    final result = await db.rawQuery('''
      SELECT SUM(duration_seconds) as total
      FROM app_sessions
      WHERE date = ?
    ''', [dateKey]);

    return (result.first['total'] as int? ?? 0) ~/ 60;
  }

  // ── Location History ──────────────────────────────────────────────────────

  Future<void> insertLocation({
    required double latitude,
    required double longitude,
    String? address,
    String? placeName,
    int durationSeconds = 0,
  }) async {
    final db = await database;
    await db.insert('location_history', {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'place_name': placeName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'duration_seconds': durationSeconds,
    });
  }

  Future<List<Map<String, dynamic>>> getLocationsForDay(DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;

    return db.query(
      'location_history',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'timestamp ASC',
    );
  }

  // ── Daily Summaries ──────────────────────────────────────────────────────

  Future<void> saveDailySummary(DailySummary summary) async {
    final db = await database;
    await db.insert(
      'daily_summaries',
      summary.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DailySummary?> getDailySummary(DateTime day) async {
    final db = await database;
    final dateKey = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;

    final maps = await db.query(
      'daily_summaries',
      where: 'date = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DailySummary.fromMap(maps.first);
  }

  Future<List<DailySummary>> getRecentSummaries(int days) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

    final maps = await db.query(
      'daily_summaries',
      where: 'date > ?',
      whereArgs: [cutoff],
      orderBy: 'date DESC',
    );
    return maps.map(DailySummary.fromMap).toList();
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDayStats(DateTime day) async {
    final events = await getEventsForDay(day);
    final appUsage = await getAppUsageForDay(day);
    final screenTime = await getTotalScreenTimeForDay(day);
    final locations = await getLocationsForDay(day);

    int totalSteps = 0;
    int phonePickups = 0;
    final activities = <String>[];

    for (final event in events) {
      if (event.type == 'step') {
        totalSteps += int.tryParse(event.data['steps']?.toString() ?? '0') ?? 0;
      } else if (event.type == 'screen' && event.data['state'] == 'on') {
        phonePickups++;
      } else if (event.type == 'activity') {
        final act = event.data['activity'];
        if (act != null && !activities.contains(act)) {
          activities.add(act);
        }
      }
    }

    return {
      'total_screen_time_minutes': screenTime,
      'total_steps': totalSteps,
      'phone_pickups': phonePickups,
      'app_usage': appUsage,
      'activities': activities,
      'locations': locations.length,
      'events_count': events.length,
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _dateKey(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> cleanOldData(int keepDays) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: keepDays)).millisecondsSinceEpoch;
    await db.delete('life_events', where: 'timestamp < ?', whereArgs: [cutoff]);
    await db.delete('app_sessions', where: 'start_time < ?', whereArgs: [cutoff]);
    await db.delete('location_history', where: 'timestamp < ?', whereArgs: [cutoff]);
  }
}
