import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/life_event.dart';
import '../models/daily_summary.dart';
import '../models/chat_message.dart';
import '../models/trusted_contact.dart';
import '../models/safety_incident.dart';

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
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── Life tracking tables ──────────────────────────────────────────────────
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

    // One row per app per day — cumulative daily usage
    await db.execute('''
      CREATE TABLE app_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        app_name TEXT,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        UNIQUE(package_name, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_steps (
        date TEXT PRIMARY KEY,
        steps INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_pickups (
        date TEXT PRIMARY KEY,
        count INTEGER NOT NULL DEFAULT 0
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

    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        is_daily INTEGER DEFAULT 0
      )
    ''');

    // ── Safety tables ─────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE trusted_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        relation TEXT DEFAULT '',
        priority INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE safety_incidents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at INTEGER NOT NULL,
        resolved_at INTEGER,
        threat_level TEXT NOT NULL,
        lat REAL,
        lng REAL,
        address TEXT,
        recording_path TEXT,
        is_resolved INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE safety_location_trail (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        incident_id INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // ── Indexes ───────────────────────────────────────────────────────────────
    await db.execute('CREATE INDEX idx_events_timestamp ON life_events(timestamp)');
    await db.execute('CREATE INDEX idx_events_type ON life_events(type)');
    await db.execute('CREATE INDEX idx_sessions_date ON app_sessions(date)');
    await db.execute('CREATE INDEX idx_trail_incident ON safety_location_trail(incident_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_events_timestamp ON life_events(timestamp)');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_messages (
          id TEXT PRIMARY KEY,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          is_daily INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS app_sessions');
      await db.execute('''
        CREATE TABLE app_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          package_name TEXT NOT NULL,
          app_name TEXT,
          duration_seconds INTEGER NOT NULL DEFAULT 0,
          date TEXT NOT NULL,
          UNIQUE(package_name, date)
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_date ON app_sessions(date)');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_steps (
          date TEXT PRIMARY KEY,
          steps INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_pickups (
          date TEXT PRIMARY KEY,
          count INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS trusted_contacts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          relation TEXT DEFAULT '',
          priority INTEGER DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS safety_incidents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          started_at INTEGER NOT NULL,
          resolved_at INTEGER,
          threat_level TEXT NOT NULL,
          lat REAL,
          lng REAL,
          address TEXT,
          recording_path TEXT,
          is_resolved INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS safety_location_trail (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          incident_id INTEGER NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_trail_incident ON safety_location_trail(incident_id)');
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
    final maps = await db.query('life_events', where: 'timestamp BETWEEN ? AND ?', whereArgs: [start, end], orderBy: 'timestamp ASC');
    return maps.map(LifeEvent.fromMap).toList();
  }

  Future<List<LifeEvent>> getEventsForRange(DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query('life_events', where: 'timestamp BETWEEN ? AND ?', whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch], orderBy: 'timestamp ASC');
    return maps.map(LifeEvent.fromMap).toList();
  }

  Future<List<LifeEvent>> getEventsByType(String type, DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;
    final maps = await db.query('life_events', where: 'type = ? AND timestamp BETWEEN ? AND ?', whereArgs: [type, start, end], orderBy: 'timestamp ASC');
    return maps.map(LifeEvent.fromMap).toList();
  }

  // ── App Sessions ──────────────────────────────────────────────────────────

  Future<void> upsertAppSession({
    required String packageName,
    required String? appName,
    required String dateKey,
    required int durationSeconds,
  }) async {
    if (durationSeconds < 5) return;
    final db = await database;
    await db.rawInsert('''
      INSERT INTO app_sessions (package_name, app_name, date, duration_seconds)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(package_name, date) DO UPDATE SET
        duration_seconds = excluded.duration_seconds,
        app_name = excluded.app_name
    ''', [packageName, appName ?? packageName, dateKey, durationSeconds]);
  }

  Future<void> insertAppSession({required String packageName, required String? appName, required DateTime startTime, required DateTime endTime}) async {
    await upsertAppSession(packageName: packageName, appName: appName, dateKey: _dateKey(startTime), durationSeconds: endTime.difference(startTime).inSeconds);
  }

  Future<Map<String, int>> getAppUsageForDay(DateTime day) async {
    final db = await database;
    final result = await db.rawQuery('SELECT package_name, app_name, duration_seconds FROM app_sessions WHERE date = ? ORDER BY duration_seconds DESC', [_dateKey(day)]);
    final usage = <String, int>{};
    for (final row in result) {
      final name = (row['app_name'] as String?) ?? (row['package_name'] as String);
      usage[name] = (row['duration_seconds'] as int? ?? 0) ~/ 60;
    }
    return usage;
  }

  Future<int> getTotalScreenTimeForDay(DateTime day) async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(duration_seconds) as total FROM app_sessions WHERE date = ?', [_dateKey(day)]);
    return (result.first['total'] as int? ?? 0) ~/ 60;
  }

  // ── Daily Steps ───────────────────────────────────────────────────────────

  Future<void> saveDailySteps(String dateKey, int steps) async {
    final db = await database;
    await db.rawInsert('INSERT INTO daily_steps (date, steps) VALUES (?, ?) ON CONFLICT(date) DO UPDATE SET steps = excluded.steps', [dateKey, steps]);
  }

  Future<int> getDailySteps(String dateKey) async {
    final db = await database;
    final result = await db.query('daily_steps', where: 'date = ?', whereArgs: [dateKey], limit: 1);
    if (result.isEmpty) return 0;
    return result.first['steps'] as int? ?? 0;
  }

  // ── Daily Pickups ─────────────────────────────────────────────────────────

  Future<void> saveDailyPickups(String dateKey, int count) async {
    final db = await database;
    await db.rawInsert('INSERT INTO daily_pickups (date, count) VALUES (?, ?) ON CONFLICT(date) DO UPDATE SET count = excluded.count', [dateKey, count]);
  }

  Future<int> getDailyPickups(String dateKey) async {
    final db = await database;
    final result = await db.query('daily_pickups', where: 'date = ?', whereArgs: [dateKey], limit: 1);
    if (result.isEmpty) return 0;
    return result.first['count'] as int? ?? 0;
  }

  // ── Location History ──────────────────────────────────────────────────────

  Future<void> insertLocation({required double latitude, required double longitude, String? address, String? placeName, int durationSeconds = 0}) async {
    final db = await database;
    await db.insert('location_history', {'latitude': latitude, 'longitude': longitude, 'address': address, 'place_name': placeName, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'duration_seconds': durationSeconds});
  }

  Future<List<Map<String, dynamic>>> getLocationsForDay(DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;
    return db.query('location_history', where: 'timestamp BETWEEN ? AND ?', whereArgs: [start, end], orderBy: 'timestamp ASC');
  }

  // ── Daily Summaries ──────────────────────────────────────────────────────

  Future<void> saveDailySummary(DailySummary summary) async {
    final db = await database;
    await db.insert('daily_summaries', summary.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DailySummary?> getDailySummary(DateTime day) async {
    final db = await database;
    final maps = await db.query('daily_summaries', where: 'date = ?', whereArgs: [DateTime(day.year, day.month, day.day).millisecondsSinceEpoch], limit: 1);
    if (maps.isEmpty) return null;
    return DailySummary.fromMap(maps.first);
  }

  Future<List<DailySummary>> getRecentSummaries(int days) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final maps = await db.query('daily_summaries', where: 'date > ?', whereArgs: [cutoff], orderBy: 'date DESC');
    return maps.map(DailySummary.fromMap).toList();
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDayStats(DateTime day) async {
    final dateKey = _dateKey(day);
    final appUsage = await getAppUsageForDay(day);
    final screenTime = await getTotalScreenTimeForDay(day);
    final locations = await getLocationsForDay(day);
    final steps = await getDailySteps(dateKey);
    final pickups = await getDailyPickups(dateKey);
    final events = await getEventsForDay(day);
    final activities = <String>[];
    for (final event in events) {
      if (event.type == 'activity') {
        final act = event.data['activity'];
        if (act != null && !activities.contains(act)) activities.add(act);
      }
    }
    return {
      'total_screen_time_minutes': screenTime,
      'total_steps': steps,
      'phone_pickups': pickups,
      'app_usage': appUsage,
      'activities': activities,
      'locations': locations.length,
      'events_count': events.length,
    };
  }

  // ── Chat Messages ─────────────────────────────────────────────────────────

  Future<void> saveChatMessage(ChatMessage message) async {
    final db = await database;
    await db.insert('chat_messages', message.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ChatMessage>> getTodaysChatMessages() async {
    final db = await database;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59).millisecondsSinceEpoch;
    final rows = await db.query('chat_messages', where: 'timestamp >= ? AND timestamp <= ?', whereArgs: [start, end], orderBy: 'timestamp ASC');
    return rows.map((r) => ChatMessage.fromMap(r)).toList();
  }

  Future<void> clearOldChatMessages() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    await db.delete('chat_messages', where: 'timestamp < ?', whereArgs: [cutoff]);
  }

  // ── Trusted Contacts ──────────────────────────────────────────────────────

  Future<int> saveTrustedContact(TrustedContact contact) async {
    final db = await database;
    if (contact.id != null) {
      await db.update('trusted_contacts', contact.toMap(), where: 'id = ?', whereArgs: [contact.id]);
      return contact.id!;
    }
    return db.insert('trusted_contacts', contact.toMap());
  }

  Future<List<TrustedContact>> getTrustedContacts() async {
    final db = await database;
    final rows = await db.query('trusted_contacts', orderBy: 'priority ASC');
    return rows.map(TrustedContact.fromMap).toList();
  }

  Future<void> deleteTrustedContact(int id) async {
    final db = await database;
    await db.delete('trusted_contacts', where: 'id = ?', whereArgs: [id]);
  }

  // ── Safety Incidents ──────────────────────────────────────────────────────

  Future<int> startSafetyIncident({
    required ThreatLevel threatLevel,
    double? lat,
    double? lng,
    String? address,
  }) async {
    final db = await database;
    return db.insert('safety_incidents', {
      'started_at': DateTime.now().millisecondsSinceEpoch,
      'threat_level': threatLevel.key,
      'lat': lat,
      'lng': lng,
      'address': address,
      'is_resolved': 0,
    });
  }

  Future<void> updateIncidentThreat(int id, ThreatLevel level) async {
    final db = await database;
    await db.update('safety_incidents', {'threat_level': level.key}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateIncidentRecording(int id, String path) async {
    final db = await database;
    await db.update('safety_incidents', {'recording_path': path}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> resolveIncident(int id) async {
    final db = await database;
    await db.update('safety_incidents', {
      'is_resolved': 1,
      'resolved_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<SafetyIncident?> getActiveIncident() async {
    final db = await database;
    final rows = await db.query('safety_incidents', where: 'is_resolved = 0', orderBy: 'started_at DESC', limit: 1);
    if (rows.isEmpty) return null;
    return SafetyIncident.fromMap(rows.first);
  }

  Future<List<SafetyIncident>> getAllIncidents() async {
    final db = await database;
    final rows = await db.query('safety_incidents', orderBy: 'started_at DESC');
    return rows.map(SafetyIncident.fromMap).toList();
  }

  Future<void> addLocationToTrail(int incidentId, double lat, double lng) async {
    final db = await database;
    await db.insert('safety_location_trail', {
      'incident_id': incidentId,
      'latitude': lat,
      'longitude': lng,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getIncidentTrail(int incidentId) async {
    final db = await database;
    return db.query('safety_location_trail', where: 'incident_id = ?', whereArgs: [incidentId], orderBy: 'timestamp ASC');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String dateKey(DateTime dt) => _dateKey(dt);

  Future<void> cleanOldData(int keepDays) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));
    final cutoffKey = _dateKey(cutoff);
    final cutoffMs = cutoff.millisecondsSinceEpoch;
    await db.delete('life_events', where: 'timestamp < ?', whereArgs: [cutoffMs]);
    await db.delete('app_sessions', where: 'date < ?', whereArgs: [cutoffKey]);
    await db.delete('location_history', where: 'timestamp < ?', whereArgs: [cutoffMs]);
    await db.delete('daily_steps', where: 'date < ?', whereArgs: [cutoffKey]);
    await db.delete('daily_pickups', where: 'date < ?', whereArgs: [cutoffKey]);
    // Do NOT delete safety incidents — they are permanent evidence
  }
}
