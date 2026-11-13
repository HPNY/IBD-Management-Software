import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 测试库 schema（与 local_db 的 labs/备份相关表对齐）。
/// 非 `_test.dart` 命名，不会被 flutter test 当作测试用例执行。
Future<Database> openTestDb(String name) async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final path = p.join(
    await factory.getDatabasesPath(),
    '$name.db',
  );
  await factory.deleteDatabase(path);
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
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
            lab_id TEXT NOT NULL,
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
            medication_id TEXT NOT NULL,
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
          CREATE TABLE medication_checkins (
            id TEXT PRIMARY KEY,
            medication_id TEXT NOT NULL,
            date TEXT NOT NULL,
            slot TEXT NOT NULL,
            taken_at TEXT,
            created_at TEXT NOT NULL,
            UNIQUE(medication_id, date, slot)
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
            overall_feeling TEXT,
            urgency INTEGER,
            mucus INTEGER,
            bowel_count INTEGER,
            oral_ulcer INTEGER,
            joint_pain INTEGER,
            joint_pain_site TEXT,
            custom_items TEXT,
            sleep_hours REAL,
            sleep_quality INTEGER,
            sleep_insomnia INTEGER,
            night_wakes INTEGER,
            stress_level INTEGER,
            stress_source TEXT,
            data_flags INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE bathroom_records (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            time TEXT,
            stool_type INTEGER,
            urgency INTEGER,
            blood INTEGER,
            mucus INTEGER,
            notes TEXT,
            source TEXT NOT NULL DEFAULT 'manual',
            daily_count INTEGER,
            diarrhea_count INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE quality_surveys (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            kind TEXT NOT NULL,
            total INTEGER NOT NULL,
            detail_json TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE exams (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            body_part TEXT,
            findings TEXT,
            diagnosis TEXT,
            score TEXT,
            comparison TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE surgeries (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            type TEXT,
            body_part TEXT,
            findings TEXT,
            procedure TEXT,
            resected_length_cm REAL,
            anastomosis TEXT,
            surgeon TEXT,
            notes TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE food_logs (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            meal TEXT,
            foods TEXT NOT NULL,
            created_at TEXT,
            calories REAL,
            protein_g REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE drug_reviews (
            id TEXT PRIMARY KEY,
            drug_name TEXT NOT NULL,
            ibd_type TEXT,
            efficacy INTEGER NOT NULL,
            se_side_effect INTEGER NOT NULL,
            side_effect_types TEXT,
            still_using INTEGER,
            comment TEXT,
            uploaded INTEGER NOT NULL DEFAULT 0,
            created_at TEXT
          )
        ''');
      },
    ),
  );
}
