import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/db/repositories.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_db.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await openTestDb('ibders_lab_series');
  });

  tearDown(() async {
    await db.close();
  });

  test('H17：白蛋白精确匹配，不混入前白蛋白', () async {
    final repo = LabRepository(database: db);
    final series = LabSeriesRepository(database: db);
    await repo.insert(
      date: '2026-03-01',
      hospital: '三甲医院A',
      items: [
        {'nameNorm': '白蛋白', 'nameRaw': 'ALB', 'value': 45, 'unit': 'g/L'},
        {'nameNorm': '前白蛋白', 'nameRaw': 'PA', 'value': 300, 'unit': 'mg/L'},
      ],
    );

    final albumin = await series.seriesByName('白蛋白');
    expect(albumin, hasLength(1));
    expect(albumin.single['value'], 45);

    final pre = await series.seriesByName('前白蛋白');
    expect(pre, hasLength(1));
    expect(pre.single['value'], 300);
  });
}
