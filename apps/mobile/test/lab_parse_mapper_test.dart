import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/lab/lab_parse_mapper.dart';

void main() {
  test('C4：定性值与 NaN 不产生数值项', () {
    final qualitative = normalizeParseLabItem({
      'name': '隐血',
      'value': null,
      'value_text': '阴性',
    });
    expect(qualitative['value'], isNull);
    expect(qualitative['valueText'], '阴性');

    final nan = normalizeParseLabItem({
      'name': '超敏C反应蛋白',
      'value': double.nan,
    });
    expect(nan['value'], isNull, reason: 'NaN 不能进入数值列');
  });

  test('C4：运算符值保留原文，不参与数值比较', () {
    final item = normalizeParseLabItem({
      'name': '粪便钙卫蛋白',
      'value': '>1800',
      'value_text': '>1800',
    });
    expect(item['value'], isNull);
    expect(item['valueText'], '>1800');
  });
}
