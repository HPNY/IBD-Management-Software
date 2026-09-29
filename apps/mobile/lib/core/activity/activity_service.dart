/// 疾病活动度仪表盘（G1 PRD §2.6.1）：状态灯 / 倒计时 / 评分提取。
library;

/// 炎症三联：规范名 → 展示名。
const kInflammationTrio = <MapEntry<String, String>>[
  MapEntry('超敏C反应蛋白', 'CRP'),
  MapEntry('血沉', 'ESR'),
  MapEntry('粪便钙卫蛋白', '钙卫蛋白'),
];

/// 单指标灯态：green=正常 · red=偏高 · gray=无数据。
/// 依赖 lab_items.flag（录入时按参考范围计算）；low 视为 green（非炎症升高）。
String inflammationLight(String? flag) {
  if (flag == null) return 'gray';
  if (flag == 'high') return 'red';
  return 'green';
}

/// 从最近检验行列表挑出某规范名的最新一条 item。
/// labs: 每项含 items: List，item 含 nameNorm/value/unit/flag；按 date 降序传入更稳妥。
Map<String, dynamic>? latestLabItem(
  List<Map<String, dynamic>> labs,
  String nameNorm,
) {
  final sorted = [...labs]
    ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
  for (final lab in sorted) {
    final items = lab['items'];
    if (items is! List) continue;
    for (final raw in items) {
      if (raw is! Map) continue;
      if ('${raw['nameNorm'] ?? ''}' == nameNorm) {
        return Map<String, dynamic>.from(raw);
      }
    }
  }
  return null;
}

/// 距下一次计划注射的天数（可为负=已过期未打）。无待打返回 null。
int? daysUntilInjection(String? plannedDate, {DateTime? now}) {
  if (plannedDate == null || plannedDate.isEmpty) return null;
  final planned = DateTime.tryParse(plannedDate);
  if (planned == null) return null;
  final ref = (now ?? DateTime.now());
  final today = DateTime(ref.year, ref.month, ref.day);
  final target = DateTime(planned.year, planned.month, planned.day);
  return target.difference(today).inDays;
}

/// 从检查 score/findings 自由文本提取 Limberg 分级（0–4 / I–IV）。
/// 匹配失败返回 null，不抛错。
String? extractLimberg(String? score, String? findings) {
  final text = '${score ?? ''} ${findings ?? ''}';
  final m = RegExp(
    r'Limberg\s*[：:]?\s*([0-4]|[IViv]{1,4})',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  return m.group(1)!.toUpperCase();
}

/// 从检查自由文本提取 SES-CD 数值。
String? extractSesCd(String? score, String? findings) {
  final text = '${score ?? ''} ${findings ?? ''}';
  final m = RegExp(
    r'SES\s*-\s*CD\s*[：:]?\s*([0-9]+(?:\.[0-9]+)?)',
    caseSensitive: false,
  ).firstMatch(text);
  return m?.group(1);
}
