import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/features/analysis/clinical_pages.dart';
import 'package:ibd_mobile/features/symptom/symptom_page.dart';

import 'fake_ibd_repos.dart';

/// 放大测试视口，避免 ListView 懒加载导致屏外文案不在树中。
/// 打卡页含日历+睡眠压力区后更长，需更高视口。
void useTallViewport(WidgetTester tester, {double height = 4200}) {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpSymptom(
  WidgetTester tester,
  FakeSymptomRepository symptoms,
  FakeBathroomRepository bathroom,
) async {
  useTallViewport(tester);
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

Future<void> pumpBathroom(
  WidgetTester tester,
  FakeBathroomRepository bathroom,
) async {
  useTallViewport(tester);
  await tester.pumpWidget(
    MaterialApp(home: BathroomPage(repo: bathroom)),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pump();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();
  await tester.pump();
}

void main() {
  late InMemoryIbdStore store;
  late FakeSymptomRepository symptoms;
  late FakeBathroomRepository bathroom;

  setUp(() {
    store = InMemoryIbdStore();
    symptoms = FakeSymptomRepository(store);
    bathroom = FakeBathroomRepository(store);
  });

  testWidgets('打卡页展示排便细表补充字段', (tester) async {
    await pumpSymptom(tester, symptoms, bathroom);

    expect(find.text('今日打卡'), findsOneWidget);
    expect(find.text('排便次数'), findsOneWidget);
    expect(find.text('腹泻次数'), findsOneWidget);
    expect(find.text('Bristol 粪便量表'), findsOneWidget);
    expect(find.text('排便细项'), findsOneWidget);
    expect(find.text('紧迫感'), findsOneWidget);
    expect(find.text('黏液'), findsOneWidget);
    expect(find.text('擦拭有'), findsOneWidget);
    expect(find.text('保存后同步细表'), findsOneWidget);
  });

  testWidgets('填写排便细项并保存后，UI 显示已同步且数据入账', (tester) async {
    await pumpSymptom(tester, symptoms, bathroom);

    await scrollToAndTap(tester, find.text('紧迫感'));
    await scrollToAndTap(tester, find.text('黏液'));
    await scrollToAndTap(tester, find.text('擦拭有'));
    await scrollToAndTap(tester, find.text('糊状或水样，边缘糊化'));
    await scrollToAndTap(tester, find.text('保存今日打卡'));

    expect(find.text('已保存到本机'), findsOneWidget);
    expect(find.text('已同步细表'), findsOneWidget);
    expect(
      find.text('排便细项已同步到「分析 · 排便细表」，无需再填一遍。'),
      findsOneWidget,
    );

    final date = uiTodayIso();
    final diary = store.symptoms[date];
    expect(diary, isNotNull);
    expect(diary!['urgency'], 1);
    expect(diary['mucus'], 1);
    expect(diary['bloody_stool'], 'trace');
    expect(diary['stool_type'], 6);

    final bath = store.bathrooms.where((r) => r['date'] == date).toList();
    expect(bath, hasLength(1));
    expect(bath.first['source'], 'checkin');
    expect(bath.first['stool_type'], 6);
    expect(bath.first['urgency'], 1);
    expect(bath.first['mucus'], 1);
    expect(bath.first['blood'], 1);
  });

  testWidgets('已有打卡数据时，页面回显并展示同步状态', (tester) async {
    final date = uiTodayIso();
    await symptoms.upsert(
      date: date,
      painLevel: 5,
      diarrheaCount: 3,
      stoolType: 7,
      bloodyStool: 'obvious',
      urgency: true,
      mucus: true,
      bowelCount: 6,
      overallFeeling: 'worse',
      nausea: true,
    );

    await pumpSymptom(tester, symptoms, bathroom);

    expect(find.text('已保存'), findsOneWidget);
    expect(find.text('已同步细表'), findsOneWidget);
    expect(find.text('已保存到本机'), findsOneWidget);
    expect(find.text('7 型'), findsOneWidget);
    expect(find.text('6 次'), findsOneWidget);
    expect(find.text('3 次'), findsWidgets);
    expect(find.text('明显'), findsOneWidget);
    expect(find.text('今日排便细表记录'), findsOneWidget);
  });

  testWidgets('排便细表页区分打卡同步与手记，并展示便血分级', (tester) async {
    final date = uiTodayIso();
    await bathroom.insert(
      date: date,
      time: '08:20',
      stoolType: 4,
      urgency: false,
      blood: false,
      mucus: false,
      notes: '早餐后手记',
    );
    await symptoms.upsert(
      date: date,
      stoolType: 6,
      bloodyStool: 'trace',
      urgency: true,
      mucus: true,
      bowelCount: 5,
      diarrheaCount: 2,
    );

    await pumpBathroom(tester, bathroom);

    expect(find.text('排便记录'), findsOneWidget);
    expect(find.text('打卡同步'), findsOneWidget);
    expect(find.text('细表手记'), findsOneWidget);
    expect(find.textContaining('擦拭有血'), findsOneWidget);
    expect(find.textContaining('当日累计 5 次'), findsOneWidget);
    expect(find.textContaining('腹泻 2 次'), findsOneWidget);
  });

  testWidgets('在排便细表页手记一笔，不会变成打卡同步', (tester) async {
    await pumpBathroom(tester, bathroom);
    expect(find.text('暂无记录'), findsOneWidget);

    await scrollToAndTap(tester, find.text('记一笔'));

    expect(find.text('暂无记录'), findsNothing);
    expect(find.text('细表手记'), findsOneWidget);
    expect(find.text('打卡同步'), findsNothing);

    final date = uiTodayIso();
    final rows = store.bathrooms.where((r) => r['date'] == date).toList();
    expect(rows, hasLength(1));
    expect(rows.first['source'], 'manual');
  });

  testWidgets('打卡 → 细表端到端：UI 完成后细表无需再填', (tester) async {
    await pumpSymptom(tester, symptoms, bathroom);
    await scrollToAndTap(tester, find.text('紧迫感'));
    await scrollToAndTap(tester, find.text('保存今日打卡'));
    expect(find.text('已同步细表'), findsOneWidget);

    await pumpBathroom(tester, bathroom);
    expect(find.text('打卡同步'), findsOneWidget);
    expect(find.text('暂无记录'), findsNothing);
    expect(
      find.text('完成「今日打卡」会自动写入对应历史，无需在本页重复填写。'),
      findsOneWidget,
    );

    await scrollToAndTap(tester, find.text('记一笔'));
    final date = uiTodayIso();
    var rows = store.bathrooms.where((r) => r['date'] == date).toList();
    expect(rows, hasLength(2));
    expect(
      rows.map((r) => r['source']).toSet(),
      containsAll(['checkin', 'manual']),
    );

    await pumpSymptom(tester, symptoms, bathroom);
    await scrollToAndTap(tester, find.text('已保存到本机'));
    rows = store.bathrooms.where((r) => r['date'] == date).toList();
    expect(
      rows.where((r) => r['source'] == 'checkin'),
      hasLength(1),
    );
  });
}
