import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/lab/lab_panels.dart';

void main() {
  test('大项模板含 IBD 核心指标，名称与趋势页规范名一致', () {
    final core = labPanelById('ibd_core');
    expect(core, isNotNull);
    final names = core!.items.map((e) => e.nameNorm).toSet();
    expect(
      names.containsAll([
        '超敏C反应蛋白',
        '血沉',
        '粪便钙卫蛋白',
        '淋巴细胞',
        '白蛋白',
        '血红蛋白',
        '尿酸',
      ]),
      isTrue,
    );
  });

  test('小项带出单位与参考范围', () {
    final crp = labPanelById('ibd_core')!
        .items
        .firstWhere((e) => e.nameNorm == '超敏C反应蛋白');
    expect(crp.unit, 'mg/L');
    expect(crp.refMax, 5.0);
    expect(crp.flagOf(8.2), 'high');
    expect(crp.flagOf(2.1), isNull);
  });

  test('合并多个大项时按规范名去重，保留先出现的模板', () {
    final merged = mergeLabItems(['ibd_core', 'cbc']);
    final hb = merged.where((e) => e.nameNorm == '血红蛋白').toList();
    expect(hb.length, 1);
    expect(hb.first.unit, 'g/L');
    expect(merged.any((e) => e.nameNorm == '白细胞计数'), isTrue);
  });

  test('未选大项时合并结果为空', () {
    expect(mergeLabItems(const []), isEmpty);
  });
}
