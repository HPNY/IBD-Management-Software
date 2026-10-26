import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/db/local_db.dart';

import 'test_db_harness.dart';

/// T1：腹胀（bloating）与疲劳（fatigue）独立存储的仓库层回归。
void main() {
  late TestDbHarness h;

  setUp(() async {
    h = await TestDbHarness.open(name: 'bloating_repo');
  });

  tearDown(() async {
    await h.dispose();
  });

  test('腹胀与疲劳独立往返，不再互串', () async {
    await h.symptoms.upsert(
      date: '2026-10-01',
      bloating: 3,
      fatigue: 8,
    );
    final row = await h.symptoms.getByDate('2026-10-01');
    expect(row, isNotNull);
    expect(row!['bloating'], 3);
    expect(row['fatigue'], 8);
  });

  test('录入真实腹胀值后自动解除修复标记', () async {
    const date = '2026-10-02';
    await h.symptoms.upsert(date: date, fatigue: 6);
    // 模拟迁移产物：脏行被置空并打 bit0 标记
    await h.db.update(
      'symptom_diaries',
      {'data_flags': kDataFlagBloatingReset},
      where: 'date = ?',
      whereArgs: [date],
    );

    // 未提供腹胀值的保存：标记保留（提示继续可见）
    await h.symptoms.upsert(date: date, painLevel: 4);
    var row = await h.symptoms.getByDate(date);
    expect(row!['data_flags'], kDataFlagBloatingReset);
    expect(row['bloating'], isNull);

    // 提供真实腹胀值：标记解除
    await h.symptoms.upsert(date: date, bloating: 2);
    row = await h.symptoms.getByDate(date);
    expect(row!['bloating'], 2);
    expect(row['data_flags'], 0);
  });

  test('新行默认无标记', () async {
    await h.symptoms.upsert(date: '2026-10-03', bloating: 5, fatigue: 1);
    final row = await h.symptoms.getByDate('2026-10-03');
    expect(row!['data_flags'], 0);
  });
}
