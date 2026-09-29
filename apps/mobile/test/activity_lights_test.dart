import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/activity/activity_service.dart';

void main() {
  group('inflammationLight', () {
    test('high→red · 正常/low→green · 无→gray', () {
      expect(inflammationLight('high'), 'red');
      expect(inflammationLight(null), 'gray');
      expect(inflammationLight('low'), 'green');
      expect(inflammationLight(''), 'green'); // 非 high 即非红
    });
  });

  group('latestLabItem', () {
    test('按日期取最新匹配项', () {
      final labs = [
        {
          'date': '2026-09-01',
          'items': [
            {'nameNorm': '超敏C反应蛋白', 'value': 8.0, 'flag': 'high'},
          ],
        },
        {
          'date': '2026-08-01',
          'items': [
            {'nameNorm': '超敏C反应蛋白', 'value': 2.0, 'flag': null},
          ],
        },
      ];
      final latest = latestLabItem(labs, '超敏C反应蛋白');
      expect(latest!['value'], 8.0);
      expect(latest['flag'], 'high');
    });

    test('无匹配返回 null', () {
      expect(latestLabItem([], '血沉'), isNull);
    });
  });

  group('daysUntilInjection', () {
    final now = DateTime(2026, 9, 20);
    test('未来 3 天', () {
      expect(daysUntilInjection('2026-09-23', now: now), 3);
    });
    test('今天', () {
      expect(daysUntilInjection('2026-09-20', now: now), 0);
    });
    test('过期', () {
      expect(daysUntilInjection('2026-09-18', now: now), -2);
    });
    test('空/非法 → null', () {
      expect(daysUntilInjection(null), isNull);
      expect(daysUntilInjection(''), isNull);
      expect(daysUntilInjection('not-a-date'), isNull);
    });
  });

  group('extractLimberg', () {
    test('score 字段', () {
      expect(extractLimberg('Limberg II', null), 'II');
      expect(extractLimberg('Limberg: 3', null), '3');
    });
    test('findings 字段', () {
      expect(extractLimberg(null, '腹部超声：Limberg III 级'), 'III');
    });
    test('无匹配 → null', () {
      expect(extractLimberg('正常', '肠壁增厚'), isNull);
      expect(extractLimberg(null, null), isNull);
    });
  });

  group('extractSesCd', () {
    test('score / findings', () {
      expect(extractSesCd('SES-CD 12', null), '12');
      expect(extractSesCd(null, 'SES-CD：6.5 分'), '6.5');
      expect(extractSesCd('SESCD 3', null), isNull); // 必须有连字符
    });
    test('无匹配 → null', () {
      expect(extractSesCd('Mayo 2', null), isNull);
    });
  });
}
