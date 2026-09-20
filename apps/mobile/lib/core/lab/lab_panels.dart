/// 手动录入检验：大项模板 → 自动带出小项名称/单位/参考范围。
/// nameNorm 与趋势/发作预警使用的规范中文名保持一致。
class LabItemSpec {
  const LabItemSpec({
    required this.nameNorm,
    this.nameRaw,
    required this.unit,
    this.refMin,
    this.refMax,
  });

  final String nameNorm;
  final String? nameRaw;
  final String unit;
  final double? refMin;
  final double? refMax;

  String get displayRef {
    final min = refMin;
    final max = refMax;
    if (min != null && max != null) return '$min–$max';
    if (max != null) return '<$max';
    if (min != null) return '>$min';
    return '';
  }

  /// high / low / null；未填参考范围时不标注。
  String? flagOf(double value) {
    final max = refMax;
    final min = refMin;
    if (max != null && value > max) return 'high';
    if (min != null && value < min) return 'low';
    return null;
  }
}

class LabPanel {
  const LabPanel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.items,
  });

  final String id;
  final String title;
  final String? subtitle;
  final List<LabItemSpec> items;
}

/// 常用检验大项。覆盖 IBD 核心指标与常见复查组合。
const List<LabPanel> kLabPanels = [
  LabPanel(
    id: 'ibd_core',
    title: 'IBD 核心',
    subtitle: '炎症 · 贫血 · 营养',
    items: [
      LabItemSpec(
        nameNorm: '超敏C反应蛋白',
        nameRaw: 'hs-CRP',
        unit: 'mg/L',
        refMax: 5.0,
      ),
      LabItemSpec(nameNorm: '血沉', nameRaw: 'ESR', unit: 'mm/h', refMax: 15),
      LabItemSpec(
        nameNorm: '粪便钙卫蛋白',
        nameRaw: 'FC',
        unit: 'μg/g',
        refMax: 200,
      ),
      LabItemSpec(
        nameNorm: '淋巴细胞',
        nameRaw: 'LYM',
        unit: '10^9/L',
        refMin: 1.1,
        refMax: 3.2,
      ),
      LabItemSpec(
        nameNorm: '白蛋白',
        nameRaw: 'ALB',
        unit: 'g/L',
        refMin: 40,
        refMax: 55,
      ),
      LabItemSpec(
        nameNorm: '血红蛋白',
        nameRaw: 'Hb',
        unit: 'g/L',
        refMin: 130,
        refMax: 175,
      ),
      LabItemSpec(
        nameNorm: '尿酸',
        nameRaw: 'UA',
        unit: 'μmol/L',
        refMin: 208,
        refMax: 428,
      ),
    ],
  ),
  LabPanel(
    id: 'cbc',
    title: '血常规',
    subtitle: '五分类常用项',
    items: [
      LabItemSpec(
        nameNorm: '白细胞计数',
        nameRaw: 'WBC',
        unit: '10^9/L',
        refMin: 3.5,
        refMax: 9.5,
      ),
      LabItemSpec(
        nameNorm: '中性粒细胞',
        nameRaw: 'NEUT',
        unit: '10^9/L',
        refMin: 1.8,
        refMax: 6.3,
      ),
      LabItemSpec(
        nameNorm: '淋巴细胞',
        nameRaw: 'LYM',
        unit: '10^9/L',
        refMin: 1.1,
        refMax: 3.2,
      ),
      LabItemSpec(
        nameNorm: '血红蛋白',
        nameRaw: 'Hb',
        unit: 'g/L',
        refMin: 130,
        refMax: 175,
      ),
      LabItemSpec(
        nameNorm: '血小板计数',
        nameRaw: 'PLT',
        unit: '10^9/L',
        refMin: 125,
        refMax: 350,
      ),
      LabItemSpec(
        nameNorm: '红细胞压积',
        nameRaw: 'HCT',
        unit: '%',
        refMin: 40,
        refMax: 50,
      ),
    ],
  ),
  LabPanel(
    id: 'inflammation',
    title: '炎症指标',
    subtitle: 'CRP / 血沉 / 钙卫蛋白',
    items: [
      LabItemSpec(
        nameNorm: '超敏C反应蛋白',
        nameRaw: 'hs-CRP',
        unit: 'mg/L',
        refMax: 5.0,
      ),
      LabItemSpec(
        nameNorm: 'C反应蛋白',
        nameRaw: 'CRP',
        unit: 'mg/L',
        refMax: 8.0,
      ),
      LabItemSpec(nameNorm: '血沉', nameRaw: 'ESR', unit: 'mm/h', refMax: 15),
      LabItemSpec(
        nameNorm: '粪便钙卫蛋白',
        nameRaw: 'FC',
        unit: 'μg/g',
        refMax: 200,
      ),
      LabItemSpec(
        nameNorm: '降钙素原',
        nameRaw: 'PCT',
        unit: 'ng/mL',
        refMax: 0.05,
      ),
    ],
  ),
  LabPanel(
    id: 'liver',
    title: '肝功能',
    subtitle: '转氨酶 · 胆红素 · 蛋白',
    items: [
      LabItemSpec(
        nameNorm: '丙氨酸氨基转移酶',
        nameRaw: 'ALT',
        unit: 'U/L',
        refMax: 40,
      ),
      LabItemSpec(
        nameNorm: '天门冬氨酸氨基转移酶',
        nameRaw: 'AST',
        unit: 'U/L',
        refMax: 40,
      ),
      LabItemSpec(
        nameNorm: '白蛋白',
        nameRaw: 'ALB',
        unit: 'g/L',
        refMin: 40,
        refMax: 55,
      ),
      LabItemSpec(
        nameNorm: '总胆红素',
        nameRaw: 'TBIL',
        unit: 'μmol/L',
        refMin: 3.4,
        refMax: 20.5,
      ),
      LabItemSpec(
        nameNorm: '直接胆红素',
        nameRaw: 'DBIL',
        unit: 'μmol/L',
        refMax: 6.8,
      ),
      LabItemSpec(
        nameNorm: 'γ-谷氨酰转肽酶',
        nameRaw: 'GGT',
        unit: 'U/L',
        refMax: 50,
      ),
      LabItemSpec(
        nameNorm: '碱性磷酸酶',
        nameRaw: 'ALP',
        unit: 'U/L',
        refMin: 45,
        refMax: 125,
      ),
    ],
  ),
  LabPanel(
    id: 'kidney_metabolic',
    title: '肾功能代谢',
    subtitle: '尿酸 · 肌酐 · 电解质',
    items: [
      LabItemSpec(
        nameNorm: '尿酸',
        nameRaw: 'UA',
        unit: 'μmol/L',
        refMin: 208,
        refMax: 428,
      ),
      LabItemSpec(
        nameNorm: '肌酐',
        nameRaw: 'Cr',
        unit: 'μmol/L',
        refMin: 41,
        refMax: 81,
      ),
      LabItemSpec(
        nameNorm: '尿素氮',
        nameRaw: 'BUN',
        unit: 'mmol/L',
        refMin: 2.9,
        refMax: 8.2,
      ),
      LabItemSpec(
        nameNorm: '估算肾小球滤过率',
        nameRaw: 'eGFR',
        unit: 'mL/min',
        refMin: 90,
      ),
      LabItemSpec(
        nameNorm: '钾',
        nameRaw: 'K',
        unit: 'mmol/L',
        refMin: 3.5,
        refMax: 5.3,
      ),
      LabItemSpec(
        nameNorm: '钠',
        nameRaw: 'Na',
        unit: 'mmol/L',
        refMin: 137,
        refMax: 147,
      ),
      LabItemSpec(
        nameNorm: '钙',
        nameRaw: 'Ca',
        unit: 'mmol/L',
        refMin: 2.11,
        refMax: 2.52,
      ),
    ],
  ),
  LabPanel(
    id: 'nutrition_anemia',
    title: '营养贫血',
    subtitle: '铁代谢 · 维生素',
    items: [
      LabItemSpec(
        nameNorm: '血红蛋白',
        nameRaw: 'Hb',
        unit: 'g/L',
        refMin: 130,
        refMax: 175,
      ),
      LabItemSpec(
        nameNorm: '血清铁蛋白',
        nameRaw: 'Ferritin',
        unit: 'μg/L',
        refMin: 30,
        refMax: 400,
      ),
      LabItemSpec(
        nameNorm: '维生素B12',
        nameRaw: 'VB12',
        unit: 'pmol/L',
        refMin: 145,
        refMax: 569,
      ),
      LabItemSpec(
        nameNorm: '叶酸',
        nameRaw: 'Folate',
        unit: 'nmol/L',
        refMin: 7.0,
        refMax: 46.4,
      ),
      LabItemSpec(
        nameNorm: '白蛋白',
        nameRaw: 'ALB',
        unit: 'g/L',
        refMin: 40,
        refMax: 55,
      ),
      LabItemSpec(
        nameNorm: '前白蛋白',
        nameRaw: 'PA',
        unit: 'mg/L',
        refMin: 200,
        refMax: 400,
      ),
    ],
  ),
];

LabPanel? labPanelById(String id) {
  for (final p in kLabPanels) {
    if (p.id == id) return p;
  }
  return null;
}

/// 按 nameNorm 合并多个大项，后选的大项不覆盖已填数值。
List<LabItemSpec> mergeLabItems(Iterable<String> panelIds) {
  final seen = <String>{};
  final out = <LabItemSpec>[];
  for (final id in panelIds) {
    final panel = labPanelById(id);
    if (panel == null) continue;
    for (final item in panel.items) {
      if (seen.add(item.nameNorm)) out.add(item);
    }
  }
  return out;
}
