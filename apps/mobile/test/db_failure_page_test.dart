import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/ui/theme.dart';
import 'package:ibd_mobile/features/recovery/db_failure_page.dart';

/// U16 回归：本地库打不开时必须给出可理解的恢复界面，而不是满屏空白。
void main() {
  testWidgets('恢复页展示原因、两条出路与排查线索', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIbdTheme(),
        home: DbFailurePage(
          error: Exception('file is not a database (code 26)'),
          onRecovered: () {},
        ),
      ),
    );

    expect(find.text('本机数据打不开'), findsOneWidget);
    expect(find.text('重试打开'), findsOneWidget);
    expect(find.text('清空本机数据并重建'), findsOneWidget);
    // 原始异常要能被看到，便于用户反馈
    expect(
      find.textContaining('file is not a database'),
      findsOneWidget,
    );
  });

  testWidgets('重建前必须二次确认，取消则不执行', (tester) async {
    var recovered = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIbdTheme(),
        home: DbFailurePage(
          error: Exception('boom'),
          onRecovered: () => recovered = true,
        ),
      ),
    );

    await tester.tap(find.text('清空本机数据并重建'));
    await tester.pumpAndSettle();

    expect(find.text('重建本地库？'), findsOneWidget);
    expect(find.textContaining('无法撤销'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('本机数据打不开'), findsOneWidget);
    expect(recovered, isFalse);
  });
}
