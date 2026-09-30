/// D1：营养粗记汇总纯函数（kcal / 蛋白；仅自管参考）。
library;

class FoodNutritionRow {
  const FoodNutritionRow({
    required this.date,
    this.calories,
    this.proteinG,
    this.foods = const [],
  });

  final String date;
  final double? calories;
  final double? proteinG;
  final List<String> foods;
}

class NutritionSummary {
  const NutritionSummary({
    required this.date,
    required this.calories,
    required this.proteinG,
    required this.entryCount,
    required this.hasData,
  });

  final String date;
  final double calories;
  final double proteinG;
  final int entryCount;
  final bool hasData;
}

/// 单日汇总：同日多条相加；全 null → hasData=false。
NutritionSummary summarizeDay(
  String date,
  List<FoodNutritionRow> rows,
) {
  final dayRows = rows.where((r) => r.date == date);
  var kcal = 0.0;
  var protein = 0.0;
  var n = 0;
  var any = false;
  for (final r in dayRows) {
    n++;
    if (r.calories != null) {
      kcal += r.calories!;
      any = true;
    }
    if (r.proteinG != null) {
      protein += r.proteinG!;
      any = true;
    }
  }
  return NutritionSummary(
    date: date,
    calories: kcal,
    proteinG: protein,
    entryCount: n,
    hasData: any,
  );
}

/// 近 N 日（含 [end]，日历日）均值；无数据日不计入分母。
({double avgKcal, double avgProtein, int daysWithKcal, int daysWithProtein})
    averageRecent(
  List<FoodNutritionRow> rows,
  String end,
  int days,
) {
  final endD = DateTime.parse(end);
  final startD = endD.subtract(Duration(days: days - 1));
  double sumK = 0, sumP = 0;
  var nK = 0, nP = 0;
  for (var i = 0; i < days; i++) {
    final d = startD.add(Duration(days: i));
    final ymd =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final s = summarizeDay(ymd, rows);
    if (!s.hasData) continue;
    if (s.calories > 0 || rows.any((r) => r.date == ymd && r.calories != null)) {
      sumK += s.calories;
      nK++;
    }
    if (s.proteinG > 0 || rows.any((r) => r.date == ymd && r.proteinG != null)) {
      sumP += s.proteinG;
      nP++;
    }
  }
  return (
    avgKcal: nK == 0 ? 0 : sumK / nK,
    avgProtein: nP == 0 ? 0 : sumP / nP,
    daysWithKcal: nK,
    daysWithProtein: nP,
  );
}

/// 食谱标签并入今日 foods 串（去重，保持顺序）。
String mergeFoodTags(String? existing, List<String> recipeTags) {
  final seen = <String>{};
  final out = <String>[
    ...?existing
        ?.split(RegExp(r'[,，、]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty),
  ];
  for (final t in out) {
    seen.add(t);
  }
  for (final t in recipeTags) {
    final x = t.trim();
    if (x.isEmpty || seen.contains(x)) continue;
    seen.add(x);
    out.add(x);
  }
  return out.join('、');
}
