import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/features/symptom/symptom_page.dart';

import 'fake_ibd_repos.dart';

/// T1.2 回归：疲劳开关关闭后保存不再残留滑块旧值（写 null = 未记录）。
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

  testWidgets('疲劳开关关闭时保存不写滑块旧值（null）', (tester) async {
    await pumpSymptom(tester, symptoms, bathroom);

    await scrollToAndTap(tester, find.text('疲劳感明显'));
    await tester.drag(
      find.byKey(const Key('symptom-fatigue-slider')),
      const Offset(600, 0),
    );
    await tester.pump();
    await scrollToAndTap(tester, find.text('疲劳感明显')); // 关闭开关
    await scrollToAndTap(tester, find.text('保存今日打卡'));

    final diary = store.symptoms[uiTodayIso()]!;
    expect(diary['fatigue'], isNull);
  });

  testWidgets('疲劳开启时正常保存滑块值', (tester) async {
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
  });

  testWidgets('已有疲劳值时正常回显', (tester) async {
    final date = uiTodayIso();
    await symptoms.upsert(date: date, fatigue: 6);

    await pumpSymptom(tester, symptoms, bathroom);

    expect(find.text('疲劳 6 / 10'), findsOneWidget);
  });
}
