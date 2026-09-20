import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/db/repositories.dart';
import 'package:ibd_mobile/features/lab/lab_manual_page.dart';

class _FakeLabRepository extends LabRepository {
  final List<Map<String, dynamic>> saved = [];

  @override
  Future<String> insert({
    required String date,
    String? hospital,
    String source = 'manual',
    required List<Map<String, dynamic>> items,
  }) async {
    saved.add({'source': source, 'items': items});
    return 'lab-test-1';
  }
}

Future<void> _pump(WidgetTester tester, _FakeLabRepository repo) async {
  tester.view.physicalSize = const Size(390, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: LabManualPage(labRepo: repo)),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('兼容旧入口：打开统一录入并默认带出 IBD 核心套餐', (tester) async {
    final repo = _FakeLabRepository();
    await _pump(tester, repo);
    expect(find.text('录入检验'), findsOneWidget);
    expect(find.text('超敏C反应蛋白'), findsOneWidget);
    expect(find.textContaining('mg/L'), findsWidgets);
  });

  testWidgets('选中血常规后填写数值可保存', (tester) async {
    final repo = _FakeLabRepository();
    await _pump(tester, repo);

    await tester.tap(find.text('血常规'));
    await tester.pump();
    expect(find.text('白细胞计数'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('lab-白细胞计数')),
      '7.2',
    );
    await tester.pump();

    await tester.ensureVisible(find.text('保存本次检验到本机'));
    await tester.tap(find.text('保存本次检验到本机'));
    await tester.pump();
    await tester.pump();

    expect(repo.saved, hasLength(1));
    final items = repo.saved.first['items'] as List;
    final wbc = items.firstWhere(
      (e) => (e as Map)['nameNorm'] == '白细胞计数',
    ) as Map;
    expect(wbc['value'], 7.2);
    expect(wbc['unit'], '10^9/L');
  });
}
