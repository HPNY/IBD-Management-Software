import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/db/repositories.dart';
import 'package:ibd_mobile/core/lab/lab_parse_mapper.dart';
import 'package:ibd_mobile/features/lab/lab_entry_page.dart';

class _FakeLabRepository extends LabRepository {
  final List<Map<String, dynamic>> saved = [];

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
    return 'lab-unified-1';
  }
}

Future<void> _pumpEntry(
  WidgetTester tester,
  LabEntryPage page,
) async {
  tester.view.physicalSize = const Size(390, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump();
  await tester.pump();
}

void main() {
  test('normalizeParseLabItem 兼容多种字段名', () {
    final m = normalizeParseLabItem({
      'name': '超敏C反应蛋白',
      'value': 12,
      'unit': 'mg/L',
      'ref_max': 5,
    });
    expect(m['nameNorm'], '超敏C反应蛋白');
    expect(m['value'], 12.0);
    expect(m['refMax'], 5.0);
  });

  testWidgets('解析服务录入：结果进入同一表单，确认后入库 source=ai', (tester) async {
    final repo = _FakeLabRepository();
    await _pumpEntry(
      tester,
      LabEntryPage(
        labRepo: repo,
        seedParsedItems: [
          {
            'nameNorm': '超敏C反应蛋白',
            'nameRaw': 'hs-CRP',
            'value': 8.2,
            'valueText': '8.2',
            'unit': 'mg/L',
            'refMax': 5.0,
          },
          {
            'nameNorm': '白细胞计数',
            'nameRaw': 'WBC',
            'value': 6.1,
            'valueText': '6.1',
            'unit': '10^9/L',
            'refMin': 3.5,
            'refMax': 9.5,
          },
        ],
      ),
    );

    expect(find.text('录入检验'), findsOneWidget);
    expect(find.textContaining('解析只为填表'), findsWidgets);
    // 同名套餐项已并入
    expect(find.text('超敏C反应蛋白'), findsOneWidget);
    expect(find.text('偏高 ↑'), findsOneWidget);
    // 非套餐项在待确认区
    expect(find.text('白细胞计数'), findsOneWidget);
    expect(find.textContaining('来源：报告解析'), findsOneWidget);
    expect(find.textContaining('已解析 2 项'), findsOneWidget);

    await tester.ensureVisible(find.text('保存本次检验到本机'));
    await tester.tap(find.text('保存本次检验到本机'));
    await tester.pump();
    await tester.pump();

    expect(repo.saved, hasLength(1));
    final rec = repo.saved.first;
    expect(rec['source'], 'ai');
    final items = rec['items'] as List;
    expect(items, hasLength(2));
    final names = items
        .map((e) => (e as Map)['nameNorm'] as String)
        .toSet();
    expect(names, {'超敏C反应蛋白', '白细胞计数'});
    final crp = items.firstWhere(
      (e) => (e as Map)['nameNorm'] == '超敏C反应蛋白',
    ) as Map;
    expect(crp['value'], 8.2);
    expect(crp['flag'], 'high');
  });

  testWidgets('仅套餐手填仍可保存 source=manual', (tester) async {
    final repo = _FakeLabRepository();
    await _pumpEntry(tester, LabEntryPage(labRepo: repo));

    expect(find.text('检验套餐'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('lab-超敏C反应蛋白')),
      '2.1',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('保存本次检验到本机'));
    await tester.tap(find.text('保存本次检验到本机'));
    await tester.pump();
    await tester.pump();

    expect(repo.saved, hasLength(1));
    expect(repo.saved.first['source'], 'manual');
    final items = repo.saved.first['items'] as List;
    expect(items, hasLength(1));
  });

  testWidgets('未选套餐且无数值时提示需填写', (tester) async {
    final repo = _FakeLabRepository();
    await _pumpEntry(
      tester,
      LabEntryPage(labRepo: repo, emphasizeParse: true),
    );
    // emphasizeParse 时不默认选中套餐
    await tester.ensureVisible(find.text('保存本次检验到本机'));
    await tester.tap(find.text('保存本次检验到本机'));
    await tester.pump();
    expect(
      find.text('请通过套餐或报告解析至少填写一项数值'),
      findsOneWidget,
    );
  });
}
