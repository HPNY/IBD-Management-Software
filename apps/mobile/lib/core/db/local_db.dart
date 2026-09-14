import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// 本地权威库（无 build_runner，便于工程化前维护）。
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'ibders_local.db');
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
    _db = db;
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE labs (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        hospital TEXT,
        source TEXT NOT NULL DEFAULT 'manual',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE lab_items (
        id TEXT PRIMARY KEY,
        lab_id TEXT NOT NULL REFERENCES labs(id) ON DELETE CASCADE,
        name_norm TEXT NOT NULL,
        name_raw TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT,
        ref_min REAL,
        ref_max REAL,
        flag TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE medications (
        id TEXT PRIMARY KEY,
        drug_name TEXT NOT NULL,
        brand_name TEXT,
        category TEXT,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        route TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        reason TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE adverse_events (
        id TEXT PRIMARY KEY,
        medication_id TEXT NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        severity TEXT NOT NULL DEFAULT 'mild',
        occurred_at TEXT NOT NULL,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE injections (
        id TEXT PRIMARY KEY,
        drug TEXT NOT NULL,
        planned_date TEXT NOT NULL,
        actual_date TEXT,
        phase TEXT NOT NULL,
        dose TEXT NOT NULL,
        route TEXT NOT NULL,
        week_number INTEGER NOT NULL,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE symptom_diaries (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        pain_level INTEGER,
        diarrhea_count INTEGER,
        stool_type INTEGER,
        bloody_stool TEXT,
        bloating INTEGER,
        fatigue INTEGER,
        nausea INTEGER,
        overall_feeling TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE parse_jobs (
        id TEXT PRIMARY KEY,
        object_key TEXT,
        hospital_hint TEXT,
        report_type TEXT,
        status TEXT NOT NULL,
        items_json TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
