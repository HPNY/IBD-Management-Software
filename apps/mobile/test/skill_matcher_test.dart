import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/skill/skill_matcher.dart';

/// T3：本地 Skill 快速匹配纯函数回归。
void main() {
  Map<String, dynamic> skill({List<Object?> items = const []}) => {
        'hospital': '某三甲医院A',
        'report_type': '血常规',
        'formatVersion': 1,
        'items': items,
      };

  test('全命中：提取数值/单位/参考范围并判 flag', () {
    const text = '白细胞计数 6.1 10^9/L\n血红蛋白 110 g/L';
    final r = matchSkill(text, skill(items: [
      {
        'name': '白细胞计数',
        'nameRaw': 'WBC',
        'pattern': '白细胞计数\\s+([\\d.]+)',
        'unit': '10^9/L',
        'refMin': 3.5,
        'refMax': 9.5,
      },
      {
        'name': '血红蛋白',
        'nameRaw': 'Hb',
        'pattern': '血红蛋白\\s+([\\d.]+)',
        'unit': 'g/L',
        'refMin': 130,
        'refMax': 175,
      },
    ]));

    expect(r.totalRules, 2);
    expect(r.matchedRules, 2);
    expect(r.isFullHit, isTrue);
    expect(r.items, hasLength(2));
    final wbc = r.items[0];
    expect(wbc['nameNorm'], '白细胞计数');
    expect(wbc['value'], 6.1);
    expect(wbc['valueText'], '6.1');
    expect(wbc['unit'], '10^9/L');
    expect(wbc['flag'], isNull);
    final hb = r.items[1];
    expect(hb['flag'], 'low'); // 110 < 130
  });

  test('超参考上限判 high', () {
    final r = matchSkill('超敏C-反应蛋白 8.2', skill(items: [
      {
        'name': '超敏C反应蛋白',
        'pattern': '超敏C-反应蛋白\\s+([\\d.]+)',
        'refMin': 0,
        'refMax': 5.0,
      },
    ]));
    expect(r.items.single['flag'], 'high');
  });

  test('部分命中不算全命中（回落云端）', () {
    final r = matchSkill('白细胞计数 6.1', skill(items: [
      {'name': '白细胞计数', 'pattern': '白细胞计数\\s+([\\d.]+)'},
      {'name': '血红蛋白', 'pattern': '血红蛋白\\s+([\\d.]+)'},
    ]));
    expect(r.matchedRules, 1);
    expect(r.isFullHit, isFalse);
  });

  test('零命中：空结果', () {
    final r = matchSkill('这份文本没有检验数值', skill(items: [
      {'name': '白细胞计数', 'pattern': '白细胞计数\\s+([\\d.]+)'},
    ]));
    expect(r.items, isEmpty);
    expect(r.isFullHit, isFalse);
  });

  test('非法正则规则安全跳过，不影响其它规则', () {
    final r = matchSkill('白细胞计数 6.1', skill(items: [
      {'name': '坏规则', 'pattern': '([\\d.+'}, // 非法正则
      {'name': '白细胞计数', 'pattern': '白细胞计数\\s+([\\d.]+)'},
    ]));
    expect(r.matchedRules, 1);
    expect(r.items.single['nameNorm'], '白细胞计数');
  });

  test('无数值匹配（非数字）不产生条目', () {
    final r = matchSkill('白细胞计数 abc', skill(items: [
      {'name': '白细胞计数', 'pattern': '白细胞计数\\s+([\\d.]+)'},
    ]));
    expect(r.items, isEmpty);
    expect(r.isFullHit, isFalse);
  });
}
