import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/features/analysis/analysis_tab.dart';

/// U7（2026-11-13）：分析 Tab 四组分层。
///
/// 原来 14 项平铺时，任一项都不需要「找」，因为这个测试也不存在。
/// 分组后风险变成：某次改动让某一项从分组里掉出去（漏迁），
/// 或者两组标题重复（视觉上分不清边界）。这两类都靠断言钉住。
void main() {
  const groups = [
    '趋势与时间线',
    '记录与明细',
    '就诊与报告',
    '分析与参考',
  ];

  const entries = [
    // 趋势与时间线
    '指标趋势',
    '病程时间线',
    // 记录与明细
    '检查与手术',
    '排便细表',
    '食物与排便',
    // 就诊与报告
    '就诊摘要',
    '年度报告',
    '我的医生',
    '生活质量量表',
    '数据导出',
    // 分析与参考
    'AI / 规则分析',
    '发作预警',
    '药物评价',
    '同城病友 · 就诊指南',
  ];

  Future<void> pumpAnalysis(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: AnalysisTab()),
    );
    await tester.pump();
  }

  testWidgets('四个分组标题各出现一次', (tester) async {
    await pumpAnalysis(tester);
    for (final g in groups) {
      expect(
        find.text(g),
        findsOneWidget,
        reason: '分组标题「$g」应恰好出现一次',
      );
    }
  });

  testWidgets('14 个入口全部在页面上，无漏迁', (tester) async {
    await pumpAnalysis(tester);
    for (final e in entries) {
      expect(
        find.text(e),
        findsOneWidget,
        reason: '入口「$e」应在分析 Tab 上出现一次',
      );
    }
  });

  testWidgets('分组顺序固定：趋势 → 明细 → 就诊 → 分析', (tester) async {
    await pumpAnalysis(tester);
    final tops = <String, double>{};
    for (final g in groups) {
      tops[g] = tester.getTopLeft(find.text(g)).dy;
    }
    for (var i = 1; i < groups.length; i++) {
      expect(
        tops[groups[i]]!,
        greaterThan(tops[groups[i - 1]]!),
        reason: '「${groups[i]}」应在「${groups[i - 1]}」下方',
      );
    }
  });

  testWidgets('每个入口都有可点击的祖先（InkWell）', (tester) async {
    await pumpAnalysis(tester);
    // 取一个代表性入口验证：分组后行内用 InkWell 承载点击，
    // 若将来换成纯 Text 会在这里断掉。
    final row = find.ancestor(
      of: find.text('发作预警'),
      matching: find.byType(InkWell),
    );
    expect(row, findsWidgets);
  });
}
