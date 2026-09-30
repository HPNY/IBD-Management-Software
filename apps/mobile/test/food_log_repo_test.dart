import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/db/repositories.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('food_logs 表可写读删（G6 v7）', () async {
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    final dbPath = p.join(
      await factory.getDatabasesPath(),
      'ibders_food_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await factory.deleteDatabase(dbPath);
    final db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE food_logs (
              id TEXT PRIMARY KEY,
              date TEXT NOT NULL,
              meal TEXT,
              foods TEXT NOT NULL,
              calories REAL,
              protein_g REAL,
              created_at TEXT
            )
          ''');
        },
      ),
    );
    addTearDown(db.close);

    final repo = FoodRepository(database: db);
    final id = await repo.insert(
      date: '2026-09-01',
      foods: '牛奶,冷饮',
      meal: '早餐',
      calories: 350,
      proteinG: 12.5,
    );
    expect(id, isNotEmpty);
    var all = await repo.listAll();
    expect(all.length, 1);
    expect(all.single['foods'], '牛奶,冷饮');
    expect(all.single['calories'], 350);
    expect(all.single['protein_g'], 12.5);
    await repo.delete(id);
    all = await repo.listAll();
    expect(all, isEmpty);
  });

  test('营养列不填为 null（D1.2）', () async {
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    final dbPath = p.join(
      await factory.getDatabasesPath(),
      'ibders_food_null_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await factory.deleteDatabase(dbPath);
    final db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE food_logs (
              id TEXT PRIMARY KEY,
              date TEXT NOT NULL,
              meal TEXT,
              foods TEXT NOT NULL,
              calories REAL,
              protein_g REAL,
              created_at TEXT
            )
          ''');
        },
      ),
    );
    addTearDown(db.close);
    final repo = FoodRepository(database: db);
    await repo.insert(date: '2026-09-02', foods: '米饭', meal: '午餐');
    final rows = await repo.listAll();
    expect(rows.single['calories'], isNull);
    expect(rows.single['protein_g'], isNull);
  });
}
