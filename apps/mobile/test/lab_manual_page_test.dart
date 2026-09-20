import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/db/repositories.dart';
import 'package:ibd_mobile/features/lab/lab_manual_page.dart';

class _FakeLabRepository extends LabRepository {
  final List<Map<String, dynamic>> saved = [];
  String nextId = 'lab-test-1';

  @override
  Future<String> insert({
    required String date,
    String? hospital,
    String source = 'manual',
    required List<Map<String, dynamic>> items,
  }) async {
    saved.add({
      'date': date,
      'hospital': hospital,
      'source': source,
      'items': items,
    });
    return nextId;
  }
}

Future<void> _pump(WidgetTester tester, _FakeLabRepository repo) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: LabManualPage(labRepo: repo)),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('选择大项后自动带出小项名称与单位', (tester) async {
    final repo = _FakeLabRepository();
    await _pump(tester, repo);

    expect(find.text('检验大项'), findsOneWidget);
    expect(find.text('IBD 核心'), findsWidgets);
    // 默认选中 IBD 核心，应出现小项卡片
    expect(find.text('超敏C反应蛋白'), findsOneWidget);
    expect(find.textContaining('mg/L'), findsWidgets);
    expect(find.textContaining('参考'), findsWidgets);
  });

  testWidgets('取消全部大项后提示选择', (tester) async {
    final repo = _FakeLabRepository();
    await _pump(tester, repo);

    await tester.tap(find.text('IBD 核心'));
    await tester.pump();
    expect(find.text('请至少选择一个检验大项'), findsOneWidget);
    expect(find.text('超敏C反应蛋白'), findsNothing);
  });

  testWidgets('选中血常规后出现白细胞计数，填写数值可保存', (tester) async {
    final repo = _FakeLabRepository();
    await _pump(tester, repo);

    await tester.tap(find.text('血常规'));
    await tester.pump();

    expect(find.text('白细胞计数'), findsOneWidget);
    expect(find.textContaining('10^9/L'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('lab-白细胞计数')),
      '7.2',
    );
    await tester.pump();

    await tester.ensureVisible(find.text('保存到本机'));
    await tester.tap(find.text('保存到本机'));
    await tester.pump();
    await tester.pump();

    expect(repo.saved, hasLength(1));
    final items = repo.saved.first['items'] as List;
    expect(items, hasLength(1));
    final item = items.first as Map<String, dynamic>;
    expect(item['nameNorm'], '白细胞计数');
    expect(item['value'], 7.2);
    expect(item['unit'], '10^9/L');
    expect(item['refMin'], 3.5);
    expect(item['refMax'], 9.5);
    expect(item['flag'], isNull);
    expect(find.textContaining('已保存'), findsOneWidget);
  });

  testWidgets('超出参考范围时展示偏高并写入 flag', (tester) async {
    final repo = _FakeLabRepository();
    await _pump(tester, repo);

    await tester.enterText(
      find.byKey(const ValueKey('lab-超敏C反应蛋白')),
      '12.5',
    );
    await tester.pump();
    expect(find.text('偏高 ↑'), findsOneWidget);

    await tester.ensureVisible(find.text('保存到本机'));
    await tester.tap(find.text('保存到本机'));
    await tester.pump();
    await tester.pump();

    final items = repo.saved.first['items'] as List;
    expect(items, hasLength(1));
    expect((items.first as Map)['flag'], 'high');
  });
}
