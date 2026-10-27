import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/ui/disclaimer.dart';

/// T7：非诊断/非治疗声明组件回归。
void main() {
  testWidgets('DisclaimerFooter 渲染非诊断声明', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DisclaimerFooter())),
    );
    await tester.pump();

    expect(find.text(kNonMedicalDisclaimer), findsOneWidget);
    expect(kNonMedicalDisclaimer, contains('非诊断'));
    expect(kNonMedicalDisclaimer, contains('非治疗建议'));
    expect(kNonMedicalDisclaimer, contains('遵医嘱'));
  });
}
