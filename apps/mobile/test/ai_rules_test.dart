import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/ai/ai_rules.dart';

void main() {
  test('trendDirection：升/降/稳定/未知', () {
    expect(trendDirection([1, 1.1, 1.2, 1.5, 2, 2.5]), TrendDirection.rising);
    expect(trendDirection([3, 2.8, 2.5, 2, 1.5, 1]), TrendDirection.falling);
    expect(trendDirection([1, 1, 1, 1, 1, 1]), TrendDirection.stable);
    expect(trendDirection([1, 2]), TrendDirection.unknown);
    expect(trendDirection(<double>[]), TrendDirection.unknown);
  });

  test('summarizeSeries 输出 last/avg30/avg90', () {
    final t = summarizeSeries(name: 'CRP', values: [1, 2, 3, 4]);
    expect(t.name, 'CRP');
    expect(t.last, 4);
    expect(t.avg30, 2.5);
    expect(t.points, 4);
  });

  test('labConsecutiveRise：连续两次升高', () {
    expect(
      labConsecutiveRise(name: '钙卫蛋白', values: [10, 20, 30]).length,
      1,
    );
    expect(
      labConsecutiveRise(name: '钙卫蛋白', values: [30, 20, 10]),
      isEmpty,
    );
    expect(labConsecutiveRise(name: 'x', values: [1, 2]), isEmpty);
  });

  test('bloodStreak：连续 N 天便血', () {
    final alerts = bloodStreak(
      dates: ['2026-01-01', '2026-01-02', '2026-01-03'],
      hasBlood: [false, true, true],
      days: 2,
    );
    expect(alerts.length, 1);
    expect(alerts.single.kind, 'blood_streak');
    expect(
      bloodStreak(
        dates: ['2026-01-01', '2026-01-02'],
        hasBlood: [true, false],
        days: 2,
      ),
      isEmpty,
    );
  });

  test('stoolSurge：今日突增', () {
    final a = stoolSurge(dailyCounts: [2, 2, 2, 2, 2, 2, 2, 8]);
    expect(a.length, 1);
    expect(a.single.kind, 'stool_surge');
    expect(stoolSurge(dailyCounts: [2, 2]), isEmpty);
    expect(stoolSurge(dailyCounts: [2, 2, 2, 2, 2, 2, 2, 2]), isEmpty);
  });

  test('medBeforeAfter：前/后均值与变化率', () {
    final d = medBeforeAfter(
      drugName: '乌帕替尼',
      metric: 'CRP',
      labDates: ['2026-01-01', '2026-01-15', '2026-02-01', '2026-03-01'],
      labValues: [20, 22, 10, 8],
      start: '2026-02-01',
    );
    expect(d, isNotNull);
    expect(d!.beforeAvg, 21);
    expect(d.afterAvg, 9);
    expect(d.changePct, closeTo((9 - 21) / 21 * 100, 0.01));
  });
}
