import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
 
// ============================================================
//  DatabaseHelper — eine einzige Instanz für die ganze App
//  (Singleton-Pattern: es gibt nur ein Objekt, überall erreichbar)
// ============================================================
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
 
  Database? _db;
 
  // Gibt die offene Datenbank zurück — öffnet sie beim ersten Aufruf
  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }
 
  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'moto_lean.db');
 
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabelle für jeden aufgezeichneten Lauf
        await db.execute('''
          CREATE TABLE runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at TEXT
          )
        ''');
 
        // Tabelle für jede einzelne Messung, verknüpft mit einem Lauf
        await db.execute('''
          CREATE TABLE readings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id INTEGER,
            timestamp_ms INTEGER,
            roll REAL, pitch REAL, yaw REAL,
            ax REAL, ay REAL, az REAL
          )
        ''');
      },
    );
  }
 
  // Legt einen neuen Lauf an und gibt seine ID zurück
  Future<int> createRun() async {
    final db = await database;
    return db.insert('runs', {
      'started_at': DateTime.now().toIso8601String(),
    });
  }
 
  // Fügt eine einzelne Messung zu einem laufenden Run hinzu
  Future<void> insertReading({
    required int runId,
    required double roll,
    required double pitch,
    required double yaw,
    required double ax,
    required double ay,
    required double az,
  }) async {
    final db = await database;
    await db.insert('readings', {
      'run_id': runId,
      'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      'roll': roll, 'pitch': pitch, 'yaw': yaw,
      'ax': ax, 'ay': ay, 'az': az,
    });
  }
 
  // Alle Läufe, neueste zuerst
  Future<List<Map<String, dynamic>>> getRuns() async {
    final db = await database;
    return db.query('runs', orderBy: 'started_at DESC');
  }
 
  // Anzahl der Messungen für einen bestimmten Lauf
  Future<int> getReadingCount(int runId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM readings WHERE run_id = ?',
      [runId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
 
  // Alle Messungen eines Laufs, für die spätere Detailansicht
  Future<List<Map<String, dynamic>>> getReadingsForRun(int runId) async {
    final db = await database;
    return db.query(
      'readings',
      where: 'run_id = ?',
      whereArgs: [runId],
      orderBy: 'timestamp_ms ASC',
    );
  }
}
