import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/report/annual_report.dart';

void main() {
  group('defaultRecentCompleteYear', () {
    test('2026 年中 → 2025', () {
      expect(
        AnnualReportBuilder.defaultRecentCompleteYear(now: DateTime(2026, 9, 23)),
        2025,
      );
    });
    test('元旦当天仍取去年', () {
      expect(
        AnnualReportBuilder.defaultRecentCompleteYear(now: DateTime(2027, 1, 1)),
        2026,
      );
    });
  });

  group('AnnualReport 同比与汇总', () {
    AnnualReport buildSample({required int year}) {
      final r = AnnualReport(
        year: year,
        labCount: year == 2025 ? 10 : 4,
        medChanges: 2,
        symptomDays: year == 2025 ? 120 : 80,
        injectionCount: year == 2025 ? 12 : 10,
        avgPain: year == 2025 ? 3.0 : 5.0,
        labs: const [],
        meds: [
          {
            'drugName': '美沙拉嗪',
            'dosage': '1g',
            'startDate': '$year-01-01',
            'endDate': null,
            'status': 'active',
          },
        ],
        exams: year == 2025
            ? [
                {
                  'date': '$year-03-01',
                  'type': '肠镜',
                  'findings': '乙状结肠黏膜充血',
                  'score': 'SES-CD 6',
                },
              ]
            : const [],
        surgeries: year == 2025
            ? [
                {
                  'date': '$year-06-01',
                  'type': '阑尾切除',
                  'findings': '慢性阑尾炎',
                },
              ]
            : const [],
      );
      return r;
    }

    test('delta = 本年 − 上年', () {
      final cur = buildSample(year: 2026);
      cur.prev = buildSample(year: 2025);
      final d = cur.delta!;
      expect(d.labCount, 4 - 10);
      expect(d.symptomDays, 80 - 120);
      expect(d.injectionCount, 10 - 12);
      expect(d.avgPain, closeTo(2.0, 1e-9));
      expect(d.summary, contains('+2'));
      expect(d.summary, contains('-40'));
    });

    test('toText 含同比段与检查/手术汇总', () {
      final cur = buildSample(year: 2025);
      cur.prev = buildSample(year: 2024);
      final text = cur.toText();
      expect(text, contains('与上一年度（2024）对比'));
      expect(text, contains('检查汇总（1）'));
      expect(text, contains('手术汇总（1）'));
      expect(text, contains('SES-CD 6'));
      expect(text, contains('阑尾切除'));
    });

    test('无 prev 时 delta 为 null，文本有占位', () {
      final cur = buildSample(year: 2025);
      expect(cur.delta, isNull);
      expect(cur.toText(), contains('未生成上年数据'));
      expect(cur.toText(), contains('检查汇总'));
    });

    test('toJson 含 delta 与计数', () {
      final cur = buildSample(year: 2026);
      cur.prev = buildSample(year: 2025);
      final j = cur.toJson();
      expect(j['examCount'], 0);
      expect(j['delta'], isA<Map>());
      expect((j['delta'] as Map)['labCount'], -6);
      expect(j['prevYear'], 2025);
    });
  });
}
