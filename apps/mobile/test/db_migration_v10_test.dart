import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// T1：验证 v9 → v10 迁移（bloating 历史缺陷修复）。
///
/// 缺陷背景：旧代码保存打卡时写 `bloating: _fatigue.round()`，所有非空
/// bloating 均为疲劳值副本。迁移策略：置空 bloating + data_flags bit0 标记，
/// 不静默覆盖（fatigue 等其余字段不动）。
void main() {
  test('v9 → v10 迁移：脏 bloating 置空并打标记，合法空值行不受影响', () async {
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    final dbPath = p.join(
      await factory.getDatabasesPath(),
      'ibders_migration_v9_v10_test.db',
    );
    await factory.deleteDatabase(dbPath);

    // 先建 v9 形态（无 data_flags 列）
    var db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 9,
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
        },
      ),
    );

    // 三类历史行：
    // 1) corrupt：旧缺陷写入（bloating == fatigue 副本）
    // 2) corrupt-zero：旧缺陷写入且疲劳为 0（bloating = 0 非空，同样是副本）
    // 3) clean：从未写过 bloating（NULL）
    await db.insert('symptom_diaries', {
      'id': 'corrupt',
      'date': '2026-09-01',
      'bloating': 7,
      'fatigue': 7,
    });
    await db.insert('symptom_diaries', {
      'id': 'corrupt-zero',
      'date': '2026-09-02',
      'bloating': 0,
      'fatigue': 0,
    });
    await db.insert('symptom_diaries', {
      'id': 'clean',
      'date': '2026-09-03',
      'bloating': null,
      'fatigue': 3,
    });
    await db.close();

    // 以 version 10 打开，触发与 local_db v10 相同的迁移 SQL
    db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 10,
        onUpgrade: (db, from, to) async {
          if (from < 10) {
            await db.execute(
              'ALTER TABLE symptom_diaries '
              'ADD COLUMN data_flags INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute('''
              UPDATE symptom_diaries
              SET bloating = NULL,
                  data_flags = COALESCE(data_flags, 0) | 1
              WHERE bloating IS NOT NULL
            ''');
          }
        },
      ),
    );

    final rows = await db.query('symptom_diaries', orderBy: 'date');
    final byId = {for (final r in rows) '${r['id']}': r};

    // 脏行：bloating 置空 + 标记，fatigue 原样保留
    expect(byId['corrupt']!['bloating'], isNull);
    expect(byId['corrupt']!['fatigue'], 7);
    expect(byId['corrupt']!['data_flags'], 1);

    expect(byId['corrupt-zero']!['bloating'], isNull);
    expect(byId['corrupt-zero']!['fatigue'], 0);
    expect(byId['corrupt-zero']!['data_flags'], 1);

    // 干净行：不受影响、不打标记
    expect(byId['clean']!['bloating'], isNull);
    expect(byId['clean']!['fatigue'], 3);
    expect(byId['clean']!['data_flags'], 0);

    await db.close();
    await factory.deleteDatabase(dbPath);
  });
}
