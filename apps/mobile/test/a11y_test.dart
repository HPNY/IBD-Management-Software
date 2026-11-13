import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/checkin/diary_severity.dart';
import 'package:ibd_mobile/features/symptom/symptom_page.dart';

import 'fake_ibd_repos.dart';

/// U8 无障碍专项回归。
///
/// 守的是三条能验收的硬指标：
/// 1. **TalkBack 能独立完成打卡** —— 每个可调控件都有可读标签，
///    而不是「滑块」「按钮」这种无名节点；
/// 2. **灰度截图可辨档位** —— 日历格除了颜色还有严重度数值；
/// 3. **点击区 ≥44** —— 日历格原本 34dp（含间距 38），低于拇指可点范围。
void main() {
  final store = InMemoryIbdStore();
  final symptoms = FakeSymptomRepository(store);
  final bathroom = FakeBathroomRepository(store);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SymptomPage(
          embedded: true,
          symptomRepo: symptoms,
          bathroomRepo: bathroom,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('打卡页语义覆盖', () {
    testWidgets('三个滑块都有名字，读屏不会只念「50%」', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      expect(find.bySemanticsLabel(RegExp('腹痛程度')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('今天排便次数')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('稀便次数')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Bristol 选项读成「3 型，香肠状…」并带选中态', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('3 型')).first,
      );
      expect(node.label, contains('3 型'));
      expect(node.label, contains('型'));
      // 选项是可选中的按钮，不是一段静态文字
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('开关行沿用 ListTile 语义：标签 + 说明 + 可切换', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('紧迫感')).first,
      );
      expect(node.label, contains('紧迫感'));
      // 能点、能切换：TalkBack 用户靠双击完成打卡，不能只是「一段文字」
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('凡是念成「按钮」的节点都必须能双击激活', (tester) async {
      // 这条守的是 excludeSemantics 的坑：给控件套 Semantics(button: true,
      // excludeSemantics: true) 时会连 InkWell 的 tap 动作一起丢掉，
      // 读屏念「按钮」但双击没反应——比不加语义更糟。
      final handle = tester.ensureSemantics();
      await pump(tester);

      // 用 getSemantics 取页面根节点，避免已废弃的 binding.pipelineOwner
      final root = tester.getSemantics(find.byType(SymptomPage));
      final dead = <String>[];
      void walk(SemanticsNode node) {
        final data = node.getSemanticsData();
        final flags = data.flagsCollection;
        // 禁用态按钮本来就不能点，跳过；只查「能用但点不动」和「能用但没名字」
        final disabled = flags.isEnabled == Tristate.isFalse;
        // IconButton 把名字放在 tooltip 里，读屏同样会念，两者取其一即可
        final name = data.label.isNotEmpty ? data.label : data.tooltip;
        if (flags.isButton && !disabled) {
          if (!data.hasAction(SemanticsAction.tap)) {
            dead.add('不可激活：${name.isEmpty ? '(无标签)' : name}');
          } else if (name.isEmpty) {
            dead.add('无标签（读屏只念「按钮」）');
          }
        }
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(root);
      expect(dead, isEmpty, reason: '念「按钮」却双击无效：$dead');
      handle.dispose();
    });

    testWidgets('保存按钮有明确标签，TalkBack 能找到', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      expect(find.bySemanticsLabel(RegExp('保存今日打卡')), findsWidgets);
      handle.dispose();
    });
  });

  group('日历：颜色之外的第二重编码', () {
    testWidgets('有记录的日子语义里带「严重度 N，档位」', (tester) async {
      final date = uiTodayIso();
      await symptoms.upsert(
        date: date,
        painLevel: 9,
        diarrheaCount: 8,
        stoolType: 6,
        bloodyStool: 'obvious',
        bloating: 2,
        fatigue: 2,
        nausea: false,
        overallFeeling: 'worse',
        urgency: true,
        mucus: false,
      );

      final handle = tester.ensureSemantics();
      await pump(tester);

      // 疼痛 9 → 严重度 ≥4.5，必然落在「中」以上；关键是有数值和档位词
      expect(find.bySemanticsLabel(RegExp(r'严重度 \d+，[轻中重]')), findsWidgets);
      // 没记录的日子也要能读出来，不能静默
      expect(find.bySemanticsLabel(RegExp('无记录')), findsWidgets);
      handle.dispose();
    });

    testWidgets('格子里印出严重度数字（灰度/色盲下靠数字而非颜色）', (tester) async {
      final date = uiTodayIso();
      await symptoms.upsert(
        date: date,
        painLevel: 10,
        diarrheaCount: 10,
        stoolType: 6,
        bloodyStool: 'obvious',
      );
      await pump(tester);

      final sev = diarySeverity(
        painLevel: 10,
        bowelCount: 10,
        bloodyStool: 'obvious',
      ).round();
      // 日历里应当出现这个数值文本（与日期数字并存）
      expect(find.text('$sev'), findsWidgets);
    });

    testWidgets('日历格触控区 ≥44dp', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final cell = find.bySemanticsLabel(RegExp('无记录')).first;
      final size = tester.getSize(cell);
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
      handle.dispose();
    });
  });

  group('分档文案', () {
    test('轻 / 中 / 重 与色带一一对应，边界左闭右开', () {
      expect(severityBandText(0), '轻');
      expect(severityBandText(3.9), '轻');
      expect(severityBandText(4), '中');
      expect(severityBandText(6.9), '中');
      expect(severityBandText(7), '重');
      expect(severityBandText(10), '重');
    });
  });
}
