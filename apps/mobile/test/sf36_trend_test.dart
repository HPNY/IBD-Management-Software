import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/survey/sf36_scoring.dart';
import 'package:ibd_mobile/core/survey/sf36_trend.dart';

void main() {
  test('sf36TrendFromHistory 解析 domains，日期升序，跳过无 domains/非 SF36', () {
    final rows = [
      {
        'date': '2026-03-01',
        'kind': 'SF36',
        'detail_json':
            '{"band":"x","domains":{"gh":80,"pf":90,"rp":70,"bp":60,"vt":50,"sf":70,"re":75,"mh":65},"stdAverage":70}',
      },
      {
        'date': '2026-01-15',
        'kind': 'SF36',
        'detail': {
          'domains': {
            'gh': 75,
            'pf': 85,
            'rp': 65,
            'bp': 55,
            'vt': 45,
            'sf': 65,
            're': 70,
            'mh': 60,
          },
          'stdAverage': 65,
        },
      },
      {
        'date': '2026-02-01',
        'kind': 'SF36',
        'detail_json': '{"band":"legacy","scores":[1,2]}',
      },
      {
        'date': '2026-02-02',
        'kind': 'PHQ9',
        'detail_json': '{"domains":{"gh":1}}',
      },
    ];
    final points = sf36TrendFromHistory(rows);
    expect(points.length, 2);
    expect(points.first.date, '2026-01-15');
    expect(points.first.stdAverage, 65);
    expect(points.last.domains['gh'], 80);
  });

  test('domainSeries / domainSeriesDates 同步过滤与 maxPoints', () {
    final points = [
      const Sf36TrendPoint(
        date: '2026-01-01',
        domains: {'gh': 80, 'pf': 90},
        stdAverage: 85,
      ),
      const Sf36TrendPoint(
        date: '2026-02-01',
        domains: {'gh': 70},
        stdAverage: 70,
      ),
      const Sf36TrendPoint(
        date: '2026-03-01',
        domains: {'gh': 60, 'pf': 80},
        stdAverage: 70,
      ),
    ];
    final gh = domainSeries(points, 'gh');
    final ghD = domainSeriesDates(points, 'gh');
    expect(gh, [80, 70, 60]);
    expect(ghD, ['2026-01-01', '2026-02-01', '2026-03-01']);

    final pf = domainSeries(points, 'pf', maxPoints: 1);
    final pfD = domainSeriesDates(points, 'pf', maxPoints: 1);
    expect(pf, [80]);
    expect(pfD, ['2026-03-01']);
  });

  test('scoring 与 trend 契约一致：scoreAll 可喂给趋势解析', () {
    final scores = List<int>.filled(36, 4);
    final result = Sf36Scoring.scoreAll(scores);
    final rows = [
      {
        'date': '2026-04-01',
        'kind': 'SF36',
        'detail': {
          'domains': result.domains,
          'stdAverage': result.stdAverage,
        },
      },
    ];
    final points = sf36TrendFromHistory(rows);
    expect(points.single.stdAverage, 100);
    expect(points.single.domains['pf'], 100);
  });
}
