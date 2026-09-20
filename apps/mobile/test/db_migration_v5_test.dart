import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 按 local_db.dart 的历史版本演进，验证 v4 → v5 迁移 SQL。
void main() {
  test('v4 → v5 迁移：打卡/排便细表新列可写可读', () async {
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    final dbPath = p.join(
      await factory.getDatabasesPath(),
      'ibders_migration_v4_v5_test.db',
    );
    await factory.deleteDatabase(dbPath);

    // 先建 v4 形态（无新列）
    var db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
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
              overall_feeling TEXT
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
              notes TEXT
            )
          ''');
        },
      ),
    );

    // v4 旧数据
    await db.insert('symptom_diaries', {
      'id': 'old-diary',
      'date': '2026-09-10',
      'pain_level': 3,
      'diarrhea_count': 2,
      'stool_type': 5,
      'bloody_stool': 'obvious',
    });
    await db.insert('bathroom_records', {
      'id': 'old-bath',
      'date': '2026-09-10',
      'time': '09:00',
      'stool_type': 5,
      'urgency': 0,
      'blood': 1,
      'mucus': 0,
    });
    await db.close();

    // 以 version 5 打开，触发与 local_db 相同的 ALTER
    db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 5,
        onUpgrade: (db, from, to) async {
          if (from < 5) {
            await db.execute(
              'ALTER TABLE symptom_diaries ADD COLUMN urgency INTEGER',
            );
            await db.execute(
              'ALTER TABLE symptom_diaries ADD COLUMN mucus INTEGER',
            );
            await db.execute(
              'ALTER TABLE symptom_diaries ADD COLUMN bowel_count INTEGER',
            );
            await db.execute(
              "ALTER TABLE bathroom_records ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'",
            );
            await db.execute(
              'ALTER TABLE bathroom_records ADD COLUMN daily_count INTEGER',
            );
            await db.execute(
              'ALTER TABLE bathroom_records ADD COLUMN diarrhea_count INTEGER',
            );
          }
        },
      ),
    );

    final symptomCols = await db.rawQuery('PRAGMA table_info(symptom_diaries)');
    final bathCols = await db.rawQuery('PRAGMA table_info(bathroom_records)');
    expect(
      symptomCols.map((c) => '${c['name']}'),
      containsAll(['urgency', 'mucus', 'bowel_count']),
    );
    expect(
      bathCols.map((c) => '${c['name']}'),
      containsAll(['source', 'daily_count', 'diarrhea_count']),
    );

    // 旧排便记录默认 source=manual，不会被误标成打卡同步
    final oldBath = await db.query(
      'bathroom_records',
      where: 'id = ?',
      whereArgs: ['old-bath'],
    );
    expect(oldBath.single['source'], 'manual');

    // 迁移后新列可写
    await db.update(
      'symptom_diaries',
      {'urgency': 1, 'mucus': 0, 'bowel_count': 4},
      where: 'id = ?',
      whereArgs: ['old-diary'],
    );
    final diary = await db.query(
      'symptom_diaries',
      where: 'id = ?',
      whereArgs: ['old-diary'],
    );
    expect(diary.single['urgency'], 1);
    expect(diary.single['bowel_count'], 4);
    expect(diary.single['bloody_stool'], 'obvious', reason: '旧数据应保留');

    await db.close();
    await factory.deleteDatabase(dbPath);
  });
}
