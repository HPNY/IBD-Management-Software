/// 注射相关药品目录（国内 IBD 常用）+ 排期工具。
/// 大类（通用名）→ 商品名；默认间隔供「快速填入」，可改日/周。

class DrugBrand {
  const DrugBrand({required this.brand, this.note});
  final String brand;
  final String? note;
}

class DrugCategory {
  const DrugCategory({
    required this.key,
    required this.genericName,
    required this.brands,
    this.defaultInterval = 8,
    this.defaultUnit = 'weeks',
    this.mechanism = '',
  });

  final String key;
  final String genericName;
  final List<DrugBrand> brands;

  /// 默认给药间隔（生成日历用）
  final int defaultInterval;
  final String defaultUnit; // days | weeks
  final String mechanism;
}

/// 覆盖 PRD 与国内常见 IBD 生物制剂/小分子（注射为主，含少量口服备注）
const kDrugCatalog = <DrugCategory>[
  DrugCategory(
    key: 'adalimumab',
    genericName: '阿达木单抗',
    mechanism: 'TNF-α 抑制剂',
    defaultInterval: 2,
    defaultUnit: 'weeks',
    brands: [
      DrugBrand(brand: '修美乐', note: '原研 Humira'),
      DrugBrand(brand: '安健宁'),
      DrugBrand(brand: '汉达远'),
      DrugBrand(brand: '格乐立'),
      DrugBrand(brand: '苏立信'),
      DrugBrand(brand: '安佰诺'),
      DrugBrand(brand: '建达乐'),
      DrugBrand(brand: '瑞百安'),
    ],
  ),
  DrugCategory(
    key: 'infliximab',
    genericName: '英夫利西单抗',
    mechanism: 'TNF-α 抑制剂',
    defaultInterval: 8,
    defaultUnit: 'weeks',
    brands: [
      DrugBrand(brand: '类克', note: '原研 Remicade'),
      DrugBrand(brand: '因福利美'),
      DrugBrand(brand: '普利莫'),
      DrugBrand(brand: '类停'),
      DrugBrand(brand: '瑞坦'),
    ],
  ),
  DrugCategory(
    key: 'ustekinumab',
    genericName: '乌司奴单抗',
    mechanism: 'IL-12/23 抑制剂',
    defaultInterval: 8,
    defaultUnit: 'weeks',
    brands: [
      DrugBrand(brand: '喜达诺', note: '原研 Stelara'),
      DrugBrand(brand: '瑞立泽'),
    ],
  ),
  DrugCategory(
    key: 'risankizumab',
    genericName: '利生奇珠单抗',
    mechanism: 'IL-23 抑制剂',
    defaultInterval: 8,
    defaultUnit: 'weeks',
    brands: [
      DrugBrand(brand: '喜开悦', note: 'Skyrizi / Skyrizi'),
      DrugBrand(brand: '利生奇珠'),
    ],
  ),
  DrugCategory(
    key: 'vedolizumab',
    genericName: '维得利珠单抗',
    mechanism: '整合素抑制剂',
    defaultInterval: 8,
    defaultUnit: 'weeks',
    brands: [
      DrugBrand(brand: '安吉优', note: 'Entyvio'),
    ],
  ),
  DrugCategory(
    key: 'golimumab',
    genericName: '戈利木单抗',
    mechanism: 'TNF-α 抑制剂',
    defaultInterval: 4,
    defaultUnit: 'weeks',
    brands: [
      DrugBrand(brand: '新基美'),
      DrugBrand(brand: 'Simponi'),
    ],
  ),
  DrugCategory(
    key: 'certolizumab',
    genericName: '赛妥珠单抗',
    mechanism: 'TNF-α 抑制剂',
    defaultInterval: 2,
    defaultUnit: 'weeks',
    brands: [
      DrugBrand(brand: '希敏佳'),
      DrugBrand(brand: 'Cimzia'),
    ],
  ),
  DrugCategory(
    key: 'upadacitinib',
    genericName: '乌帕替尼',
    mechanism: 'JAK 抑制剂（口服，非注射）',
    defaultInterval: 1,
    defaultUnit: 'days',
    brands: [
      DrugBrand(brand: '瑞福', note: 'Rinvoq'),
    ],
  ),
];

DrugCategory? findDrugCategory(String key) {
  for (final c in kDrugCatalog) {
    if (c.key == key) return c;
  }
  return null;
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 按起始日 + 间隔生成计划日列表（含 start，共 maxCount 次）
List<DateTime> buildIntervalDates({
  required DateTime start,
  required int interval,
  required String unit,
  int maxCount = 24,
}) {
  final stepDays = unit == 'weeks' ? interval * 7 : interval;
  if (stepDays <= 0) return [start];
  return List.generate(maxCount, (i) {
    return DateTime(start.year, start.month, start.day + i * stepDays);
  });
}

/// 是否为计划注射日（同一天）
bool isInjectionDay(DateTime day, Set<String> plannedIso) {
  return plannedIso.contains(isoDate(day));
}
