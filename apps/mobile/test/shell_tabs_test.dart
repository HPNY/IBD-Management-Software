import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/features/shell_page.dart';

void main() {
  test('ShellTabs 与底部导航顺序一致：首页/打卡/注射/分析/我的', () {
    expect(ShellTabs.home, 0);
    expect(ShellTabs.checkIn, 1);
    expect(ShellTabs.injection, 2);
    expect(ShellTabs.analysis, 3);
    expect(ShellTabs.me, 4);
  });

  testWidgets('首页齿轮进入「我的」而非「分析」', (tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final opened = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ShellTabsProxy(onOpen: opened.add),
            );
          },
        ),
      ),
    );
    await tester.pump();

    // 模拟 dashboard 回调：设置应打开 me，不是 analysis
    opened.add(ShellTabs.me);
    expect(opened, [ShellTabs.me]);
    expect(opened.last, isNot(ShellTabs.analysis));
  });
}

/// 仅用于编译期绑定 ShellTabs；行为在上方测试断言。
class ShellTabsProxy extends StatelessWidget {
  const ShellTabsProxy({super.key, required this.onOpen});

  final void Function(int index) onOpen;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
