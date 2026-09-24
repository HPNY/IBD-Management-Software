import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 按 local_db.dart 的历史版本演进，验证 v5 → v6 迁移 SQL。
void main() {
  test('v5 → v6 迁移：日记补全/睡眠压力新列可写可读', () async {
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    final dbPath = p.join(
      await factory.getDatabasesPath(),
      'ibders_migration_v5_v6_test.db',
    );
    await factory.deleteDatabase(dbPath);

    // 先建 v5 形态（含 v5 列，无 v6 列）
    var db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 5,
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
              bowel_count INTEGER
            )
          ''');
        },
      ),
    );

    await db.insert('symptom_diaries', {
      'id': 'old-diary',
      'date': '2026-09-10',
      'pain_level': 3,
      'diarrhea_count': 2,
      'stool_type': 5,
      'bloody_stool': 'trace',
      'urgency': 1,
      'mucus': 0,
      'bowel_count': 4,
    });
    await db.close();

    // 以 version 6 打开，触发与 local_db 相同的 ALTER
    db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 6,
        onUpgrade: (db, from, to) async {
          if (from < 6) {
            const cols = <String, String>{
              'oral_ulcer': 'INTEGER',
              'joint_pain': 'INTEGER',
              'joint_pain_site': 'TEXT',
              'custom_items': 'TEXT',
              'sleep_hours': 'REAL',
              'sleep_quality': 'INTEGER',
              'sleep_insomnia': 'INTEGER',
              'night_wakes': 'INTEGER',
              'stress_level': 'INTEGER',
              'stress_source': 'TEXT',
            };
            for (final e in cols.entries) {
              await db.execute(
                'ALTER TABLE symptom_diaries ADD COLUMN ${e.key} ${e.value}',
              );
            }
          }
        },
      ),
    );

    final cols = await db.rawQuery('PRAGMA table_info(symptom_diaries)');
    expect(
      cols.map((c) => '${c['name']}'),
      containsAll([
        'oral_ulcer',
        'joint_pain',
        'joint_pain_site',
        'custom_items',
        'sleep_hours',
        'sleep_quality',
        'sleep_insomnia',
        'night_wakes',
        'stress_level',
        'stress_source',
      ]),
    );

    // 旧数据保留
    final old = await db.query(
      'symptom_diaries',
      where: 'id = ?',
      whereArgs: ['old-diary'],
    );
    expect(old.single['pain_level'], 3);
    expect(old.single['bloody_stool'], 'trace');

    // 迁移后新列可写可读
    await db.update(
      'symptom_diaries',
      {
        'oral_ulcer': 1,
        'joint_pain': 1,
        'joint_pain_site': '膝,踝',
        'custom_items': '[{"label":"皮疹","value":"轻"}]',
        'sleep_hours': 6.5,
        'sleep_quality': 3,
        'sleep_insomnia': 0,
        'night_wakes': 1,
        'stress_level': 7,
        'stress_source': '工作',
      },
      where: 'id = ?',
      whereArgs: ['old-diary'],
    );
    final diary = await db.query(
      'symptom_diaries',
      where: 'id = ?',
      whereArgs: ['old-diary'],
    );
    expect(diary.single['oral_ulcer'], 1);
    expect(diary.single['joint_pain_site'], '膝,踝');
    expect(diary.single['sleep_hours'], 6.5);
    expect(diary.single['stress_level'], 7);
    expect(diary.single['custom_items'], contains('皮疹'));

    await db.close();
    await factory.deleteDatabase(dbPath);
  });
}
