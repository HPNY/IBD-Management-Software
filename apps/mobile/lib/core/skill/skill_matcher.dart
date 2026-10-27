/// T3：本地 Skill 快速匹配（纯函数，可单测）。
///
/// 用途：文本报告（.txt）的本地快速通道——用 LocalSkillStore 缓存的模板规则
/// 直接提取检验项填表（文件不出设备、不上传）。PDF/图片无本地文本，
/// 走原有云端解析链路；规则未全命中也回落云端（安全回退，不劣化现状）。
library;

class SkillMatchResult {
  const SkillMatchResult({
    required this.items,
    required this.matchedRules,
    required this.totalRules,
  });

  /// 形状对齐 lab_entry `_applyParsedItems` 输入：
  /// nameNorm/nameRaw/value/valueText/unit/refMin/refMax/flag
  final List<Map<String, dynamic>> items;
  final int matchedRules;
  final int totalRules;

  /// 全部规则命中才允许走本地快速通道（医疗数据宁可回落云端）。
  bool get isFullHit => totalRules > 0 && matchedRules == totalRules;
}

/// 对 [text] 应用模板规则（`name/pattern/unit/refMin/refMax`）。
/// 非法正则/无匹配的规则安全跳过；单条提取首个数值。
SkillMatchResult matchSkill(String text, Map<String, dynamic> skill) {
  final rules = (skill['items'] as List?) ?? const [];
  final items = <Map<String, dynamic>>[];
  var matched = 0;
  for (final raw in rules) {
    final rule = Map<String, dynamic>.from(raw as Map);
    final name = '${rule['name'] ?? ''}'.trim();
    final pattern = '${rule['pattern'] ?? ''}';
    if (name.isEmpty || pattern.isEmpty) continue;
    final RegExp? re;
    try {
      re = RegExp(pattern);
    } catch (_) {
      continue; // 非法正则安全跳过（不阻断其它规则）
    }
    final m = re.firstMatch(text);
    if (m == null) continue;
    final valueText = m.groupCount >= 1 ? (m.group(1) ?? '') : m.group(0) ?? '';
    final value = double.tryParse(valueText.trim());
    if (value == null) continue;
    matched += 1;
    final refMin = (rule['refMin'] as num?)?.toDouble();
    final refMax = (rule['refMax'] as num?)?.toDouble();
    items.add({
      'nameNorm': name,
      'nameRaw': rule['nameRaw'] ?? name,
      'value': value,
      'valueText': valueText.trim(),
      if (rule['unit'] != null) 'unit': '${rule['unit']}',
      'refMin': refMin,
      'refMax': refMax,
      'flag': _flagOf(value, refMin, refMax),
    });
  }
  return SkillMatchResult(
    items: items,
    matchedRules: matched,
    totalRules: rules.length,
  );
}

String? _flagOf(double value, double? refMin, double? refMax) {
  if (refMax != null && value > refMax) return 'high';
  if (refMin != null && value < refMin) return 'low';
  return null;
}
