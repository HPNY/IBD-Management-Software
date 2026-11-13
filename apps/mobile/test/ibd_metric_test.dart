import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/activity/activity_service.dart';
import 'package:ibd_mobile/core/ui/cards.dart';
import 'package:ibd_mobile/core/ui/theme.dart';

/// U6 回归：指标组件（IbdMetric）。
///
/// 重点守的是**无障碍契约**：状态灯不能只靠颜色编码。
/// 首页三灯在 U11 补了「偏高/正常/未测」文字，但详情页当时漏了；
/// 现在两处共用同一个组件，这里用测试把约定钉住，避免再漏回去。
void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: buildIbdTheme(),
        home: Scaffold(body: Center(child: child)),
      );

  group('IbdMetric.status', () {
    testWidgets('圆点之外必须有状态文字（WCAG 1.4.1）', (tester) async {
      await tester.pumpWidget(
        wrap(const IbdMetric.status(
          label: 'CRP',
          state: '偏高',
          tone: IbdMetricTone.bad,
        )),
      );

      expect(find.text('CRP'), findsOneWidget);
      // 这条是关键：只有圆点没有文字，色盲用户读不出状态
      expect(find.text('偏高'), findsOneWidget);
    });

    testWidgets('读屏器读成一句完整语义，而不是「CRP」+ 无名圆点', (tester) async {
      await tester.pumpWidget(
        wrap(const IbdMetric.status(
          label: 'CRP',
          state: '偏高',
          tone: IbdMetricTone.bad,
        )),
      );

      final semantics = tester.getSemantics(find.byType(IbdMetric));
      expect(semantics.label, 'CRP 偏高');
      // 内部文字被 excludeSemantics 掉，不会重复朗读
      expect(find.text('偏高'), findsOneWidget);
    });

    testWidgets('详情页形态：数值 + 状态词 + 日期四段都在', (tester) async {
      await tester.pumpWidget(
        wrap(const IbdMetric.status(
          label: 'ESR',
          value: '28 mm/h',
          state: '偏高',
          caption: '2026-11-01',
          tone: IbdMetricTone.bad,
          dotSize: 18,
        )),
      );

      expect(find.text('ESR'), findsOneWidget);
      expect(find.text('28 mm/h'), findsOneWidget);
      expect(find.text('偏高'), findsOneWidget);
      expect(find.text('2026-11-01'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(IbdMetric)).label,
        'ESR 28 mm/h 偏高 2026-11-01',
      );
    });

    testWidgets('未测态也有文字，不留空', (tester) async {
      await tester.pumpWidget(
        wrap(const IbdMetric.status(label: '钙卫', state: '未测')),
      );
      expect(find.text('未测'), findsOneWidget);
    });
  });

  group('IbdMetric.stat', () {
    testWidgets('图标 + 数值 + 标签，语义为「标签 数值」', (tester) async {
      await tester.pumpWidget(
        wrap(const IbdMetric.stat(
          label: '检验记录',
          value: '12',
          icon: Icons.biotech_rounded,
        )),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('检验记录'), findsOneWidget);
      expect(find.byIcon(Icons.biotech_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(IbdMetric)).label,
        '检验记录 12',
      );
    });
  });

  group('灯态映射', () {
    test('三种灯态都有非空文字', () {
      for (final light in ['red', 'green', 'gray']) {
        expect(inflammationStateText(light).isNotEmpty, isTrue);
      }
    });

    test('灯态 → 档位：red=bad / green=ok / 其他=neutral', () {
      expect(IbdMetricTone.ofLight('red'), IbdMetricTone.bad);
      expect(IbdMetricTone.ofLight('green'), IbdMetricTone.ok);
      expect(IbdMetricTone.ofLight('gray'), IbdMetricTone.neutral);
      expect(IbdMetricTone.ofLight('unknown'), IbdMetricTone.neutral);
    });
  });
}
