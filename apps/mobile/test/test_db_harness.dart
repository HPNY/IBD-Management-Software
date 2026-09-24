import 'package:ibd_mobile/core/db/repositories.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Widget 测试用：桌面临时 SQLite，schema 对齐 local_db v6。
class TestDbHarness {
  TestDbHarness._(this.db, this.symptoms, this.bathroom);

  final Database db;
  final SymptomRepository symptoms;
  final BathroomRepository bathroom;

  static Future<TestDbHarness> open({String name = 'ui_test'}) async {
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    final dbPath = p.join(
      await factory.getDatabasesPath(),
      'ibders_${name}_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await factory.deleteDatabase(dbPath);
    final db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) async {
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
              stress_source TEXT
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
        },
      ),
    );
    return TestDbHarness._(
      db,
      SymptomRepository(database: db),
      BathroomRepository(database: db),
    );
  }

  Future<void> dispose() async {
    await db.close();
  }
}
