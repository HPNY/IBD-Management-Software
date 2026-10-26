import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/features/symptom/symptom_page.dart';

import 'fake_ibd_repos.dart';

/// T1 回归：腹胀不再误写疲劳值；腹胀/疲劳独立录入与保存。
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

  testWidgets('仅填疲劳时，腹胀不写值（null，不再复制疲劳值）', (tester) async {
    await pumpSymptom(tester, symptoms, bathroom);

    await scrollToAndTap(tester, find.text('疲劳感明显'));
    await tester.drag(
      find.byKey(const Key('symptom-fatigue-slider')),
      const Offset(600, 0),
    );
    await tester.pump();
    await scrollToAndTap(tester, find.text('保存今日打卡'));

    final diary = store.symptoms[uiTodayIso()]!;
    expect(diary['fatigue'], 10);
    // T1 核心回归：bloating 不得等于/复制 fatigue；T1.1：关态不写值
    expect(diary['bloating'], isNull);
  });

  testWidgets('腹胀滑块拖动后关闭开关，保存不残留旧值', (tester) async {
    await pumpSymptom(tester, symptoms, bathroom);

    await scrollToAndTap(tester, find.text('腹胀明显'));
    await tester.drag(
      find.byKey(const Key('symptom-bloating-slider')),
      const Offset(300, 0),
    );
    await tester.pump();
    await scrollToAndTap(tester, find.text('腹胀明显')); // 关闭开关
    await scrollToAndTap(tester, find.text('保存今日打卡'));

    final diary = store.symptoms[uiTodayIso()]!;
    expect(diary['bloating'], isNull);
  });

  testWidgets('腹胀与疲劳独立录入并分别保存', (tester) async {
    await pumpSymptom(tester, symptoms, bathroom);

    await scrollToAndTap(tester, find.text('腹胀明显'));
    await tester.drag(
      find.byKey(const Key('symptom-bloating-slider')),
      const Offset(30, 0),
    );
    await tester.pump();
    await scrollToAndTap(tester, find.text('疲劳感明显'));
    await tester.drag(
      find.byKey(const Key('symptom-fatigue-slider')),
      const Offset(600, 0),
    );
    await tester.pump();
    await scrollToAndTap(tester, find.text('保存今日打卡'));

    final diary = store.symptoms[uiTodayIso()]!;
    expect(diary['fatigue'], 10);
    expect(diary['bloating'], greaterThan(0));
    expect(diary['bloating'], lessThan(10));
    expect(diary['bloating'], isNot(diary['fatigue']));
  });

  testWidgets('已有腹胀/疲劳值时分别回显', (tester) async {
    final date = uiTodayIso();
    await symptoms.upsert(date: date, bloating: 2, fatigue: 9);

    await pumpSymptom(tester, symptoms, bathroom);

    expect(find.text('腹胀 2 / 10'), findsOneWidget);
    expect(find.text('疲劳 9 / 10'), findsOneWidget);
  });

  testWidgets('历史脏数据修复提示可见（data_flags bit0）', (tester) async {
    final date = uiTodayIso();
    store.symptoms[date] = {
      'id': 'legacy-$date',
      'date': date,
      'bloating': null,
      'fatigue': 7,
      'data_flags': 1,
    };

    await pumpSymptom(tester, symptoms, bathroom);

    expect(find.textContaining('数据修复提示'), findsOneWidget);
    expect(find.textContaining('已置空并标记'), findsOneWidget);
  });
}
