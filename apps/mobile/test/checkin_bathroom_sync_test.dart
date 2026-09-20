import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/db/repositories.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 与 local_db.dart v5 对齐的测试库 schema。
Future<Database> _openTestDb() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final dbPath = p.join(
    await factory.getDatabasesPath(),
    'ibders_checkin_bath_test.db',
  );
  await factory.deleteDatabase(dbPath);
  final db = await factory.openDatabase(
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
        await db.execute(
          'CREATE INDEX idx_bath_date ON bathroom_records (date)',
        );
        await db.execute(
          'CREATE INDEX idx_bath_source ON bathroom_records (source)',
        );
      },
    ),
  );
  return db;
}

void main() {
  late Database db;
  late SymptomRepository symptoms;
  late BathroomRepository bathroom;

  const date = '2026-09-15';

  setUp(() async {
    db = await _openTestDb();
    symptoms = SymptomRepository(database: db);
    bathroom = BathroomRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('bloodToBathroomFlag 映射三级便血', () {
    expect(SymptomRepository.bloodToBathroomFlag('none'), 0);
    expect(SymptomRepository.bloodToBathroomFlag('trace'), 1);
    expect(SymptomRepository.bloodToBathroomFlag('obvious'), 2);
    expect(SymptomRepository.bloodToBathroomFlag(null), isNull);
  });

  test('v5 迁移列存在：打卡紧迫感/黏液/排便次数 + 细表 source', () async {
    final symptomCols = await db.rawQuery('PRAGMA table_info(symptom_diaries)');
    final bathCols = await db.rawQuery('PRAGMA table_info(bathroom_records)');
    final symptomNames =
        symptomCols.map((c) => '${c['name']}').toSet();
    final bathNames = bathCols.map((c) => '${c['name']}').toSet();

    expect(symptomNames, containsAll(['urgency', 'mucus', 'bowel_count']));
    expect(
      bathNames,
      containsAll(['source', 'daily_count', 'diarrhea_count']),
    );
  });

  test('完成打卡后，排便细表出现同步历史', () async {
    await symptoms.upsert(
      date: date,
      painLevel: 4,
      diarrheaCount: 3,
      stoolType: 6,
      bloodyStool: 'trace',
      bloating: 2,
      fatigue: 3,
      nausea: true,
      overallFeeling: 'same',
      urgency: true,
      mucus: true,
      bowelCount: 5,
    );

    final diary = await symptoms.getByDate(date);
    expect(diary, isNotNull);
    expect(diary!['urgency'], 1);
    expect(diary['mucus'], 1);
    expect(diary['bowel_count'], 5);
    expect(diary['bloody_stool'], 'trace');

    final rows = await bathroom.listByDate(date);
    expect(rows, hasLength(1));
    final row = rows.first;
    expect(row['source'], 'checkin');
    expect(row['stool_type'], 6);
    expect(row['urgency'], 1);
    expect(row['mucus'], 1);
    expect(row['blood'], 1); // trace
    expect(row['daily_count'], 5);
    expect(row['diarrhea_count'], 3);
    expect(row['notes'], '打卡同步');
    expect(row['time'], isNotNull);
  });

  test('同日重复打卡会替换同步记录，不堆重复行', () async {
    await symptoms.upsert(
      date: date,
      stoolType: 5,
      bloodyStool: 'none',
      urgency: false,
      mucus: false,
      bowelCount: 2,
      diarrheaCount: 0,
      painLevel: 1,
    );
    await symptoms.upsert(
      date: date,
      stoolType: 7,
      bloodyStool: 'obvious',
      urgency: true,
      mucus: true,
      bowelCount: 8,
      diarrheaCount: 6,
      painLevel: 7,
    );

    final diaries = await symptoms.listAll();
    expect(diaries, hasLength(1), reason: '打卡表按日唯一，应被替换');

    final rows = await bathroom.listByDate(date);
    expect(rows, hasLength(1), reason: '同步记录同日只保留一条');
    final row = rows.first;
    expect(row['source'], 'checkin');
    expect(row['stool_type'], 7);
    expect(row['blood'], 2); // obvious
    expect(row['daily_count'], 8);
    expect(row['urgency'], 1);
    expect(row['mucus'], 1);
  });

  test('细表手记不会被打卡同步覆盖', () async {
    await bathroom.insert(
      date: date,
      time: '08:30',
      stoolType: 4,
      urgency: false,
      blood: false,
      mucus: false,
      notes: '早餐后',
    );

    await symptoms.upsert(
      date: date,
      stoolType: 6,
      bloodyStool: 'trace',
      urgency: true,
      mucus: false,
      bowelCount: 4,
      diarrheaCount: 2,
    );

    final rows = await bathroom.listByDate(date);
    expect(rows, hasLength(2));

    final sources = rows.map((r) => '${r['source']}').toSet();
    expect(sources, containsAll(['manual', 'checkin']));

    final manual = rows.firstWhere((r) => r['source'] == 'manual');
    expect(manual['notes'], '早餐后');
    expect(manual['time'], '08:30');
  });

  test('打卡回显：getByDate 能读回新字段', () async {
    await symptoms.upsert(
      date: date,
      painLevel: 6,
      diarrheaCount: 4,
      stoolType: 7,
      bloodyStool: 'obvious',
      nausea: false,
      overallFeeling: 'worse',
      urgency: true,
      mucus: true,
      bowelCount: 7,
    );

    final row = await symptoms.getByDate(date);
    expect(row, isNotNull);
    expect(row!['pain_level'], 6);
    expect(row['diarrhea_count'], 4);
    expect(row['stool_type'], 7);
    expect(row['bloody_stool'], 'obvious');
    expect(row['urgency'], 1);
    expect(row['mucus'], 1);
    expect(row['bowel_count'], 7);
    expect(row['overall_feeling'], 'worse');
  });
}
