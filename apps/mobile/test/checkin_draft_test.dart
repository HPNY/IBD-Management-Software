import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/features/symptom/symptom_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ibd_repos.dart';

/// U4 回归：打卡草稿落盘 / 恢复 / 保存后清除。
/// 本机执行方式（需清空代理，否则 flutter_tester 的本地 WebSocket 会被代理拦截）：
///   env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
///     flutter test --no-pub test/checkin_draft_test.dart
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

const _draftKey = 'ibd_checkin_draft_v1';

void main() {
  late InMemoryIbdStore store;
  late FakeSymptomRepository symptoms;
  late FakeBathroomRepository bathroom;

  setUp(() {
    store = InMemoryIbdStore();
    symptoms = FakeSymptomRepository(store);
    bathroom = FakeBathroomRepository(store);
  });

  testWidgets('未保存的编辑落盘为草稿，重新进入可恢复', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSymptom(tester, symptoms, bathroom);

    await scrollToAndTap(tester, find.text('紧迫感'));
    // 越过 800ms 节流窗口，让草稿真正写入
    await tester.pump(const Duration(milliseconds: 900));

    final sp = await SharedPreferences.getInstance();
    expect(sp.getString(_draftKey), isNotNull);

    // 模拟离开再进入（同一 store，今日无数据库记录）
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpSymptom(tester, symptoms, bathroom);

    expect(find.text('已恢复上次未保存的草稿'), findsOneWidget);
  });

  testWidgets('保存成功后草稿被清除', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSymptom(tester, symptoms, bathroom);

    await scrollToAndTap(tester, find.text('紧迫感'));
    await tester.pump(const Duration(milliseconds: 900));

    var sp = await SharedPreferences.getInstance();
    expect(sp.getString(_draftKey), isNotNull);

    await scrollToAndTap(tester, find.text('保存今日打卡'));
    await tester.pump();
    await tester.pump();

    sp = await SharedPreferences.getInstance();
    expect(sp.getString(_draftKey), isNull);
    expect(find.text('已保存到本机'), findsOneWidget);
  });
}
