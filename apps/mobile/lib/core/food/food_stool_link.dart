/// G6：食物标签 × 排便指标关联（纯函数，供分析入口展示）。
library;

class FoodLogEntry {
  const FoodLogEntry({
    required this.date,
    required this.tags,
    this.meal,
  });

  final String date;
  final List<String> tags;
  final String? meal;
}

class StoolDay {
  const StoolDay({
    this.diarrheaCount,
    this.stoolType,
    this.bloodyStool,
  });

  /// 当日腹泻/排便次数（symptom_diaries.diarrhea_count 或 bowel_count）。
  final int? diarrheaCount;

  /// Bristol 1–7；>=6 视为稀便。
  final int? stoolType;

  /// none / trace / obvious / null。
  final String? bloodyStool;

  bool get isDiarrhea =>
      (diarrheaCount != null && diarrheaCount! >= 3) ||
      (stoolType != null && stoolType! >= 6);

  bool get hasBlood => bloodyStool == 'trace' || bloodyStool == 'obvious';
}

class FoodStoolLink {
  const FoodStoolLink({
    required this.tag,
    required this.daysEaten,
    required this.diarrheaRateEaten,
    required this.bloodRateEaten,
    required this.avgCountEaten,
    required this.diarrheaRateBase,
    required this.bloodRateBase,
    required this.avgCountBase,
  });

  final String tag;
  final int daysEaten;
  final double diarrheaRateEaten;
  final double bloodRateEaten;
  final double avgCountEaten;
  final double diarrheaRateBase;
  final double bloodRateBase;
  final double avgCountBase;

  /// 排便风险提示：吃该食物时腹泻率比未吃时高出 ≥0.2。
  bool get suspiciousDiarrhea =>
      daysEaten >= 3 && diarrheaRateEaten - diarrheaRateBase >= 0.2;

  bool get suspiciousBlood =>
      daysEaten >= 3 && bloodRateEaten - bloodRateBase >= 0.2;
}

/// 解析 `foods` 字段（逗号/顿号分隔），去空白与空串。
List<String> parseFoodTags(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .split(RegExp(r'[,，、]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// 按「当日/次日」窗口统计每个食物标签与排便指标的关联。
///
/// [foods]：食物日志；[stoolByDate]：日期 → 排便日指标。
/// 日期须为 `yyyy-MM-dd`；次日窗口用自然日 +1（仅在有次日数据时计入）。
List<FoodStoolLink> foodStoolLinks({
  required List<FoodLogEntry> foods,
  required Map<String, StoolDay> stoolByDate,
}) {
  final byTag = <String, Set<String>>{};
  for (final f in foods) {
    for (final t in f.tags) {
      byTag.putIfAbsent(t, () => <String>{}).add(f.date);
    }
  }
  if (byTag.isEmpty) return const [];

  String addDay(String ymd, int delta) {
    final d = DateTime.parse(ymd).add(Duration(days: delta));
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  final allDates = stoolByDate.keys.toSet();
  final out = <FoodStoolLink>[];
  for (final e in byTag.entries) {
    final eaten = e.value;
    final eatenDays = <String>{};
    final baseDays = <String>{};
    for (final date in allDates) {
      final window = {date, addDay(date, -1)}; // 当日或昨日吃过
      if (window.any(eaten.contains)) {
        eatenDays.add(date);
      } else {
        baseDays.add(date);
      }
    }

    double rate(Iterable<String> days, bool Function(StoolDay) pred) {
      if (days.isEmpty) return 0;
      var n = 0;
      for (final d in days) {
        final s = stoolByDate[d];
        if (s != null && pred(s)) n++;
      }
      return n / days.length;
    }

    double avgCount(Iterable<String> days) {
      if (days.isEmpty) return 0;
      var sum = 0.0;
      var n = 0;
      for (final d in days) {
        final c = stoolByDate[d]?.diarrheaCount;
        if (c != null) {
          sum += c;
          n++;
        }
      }
      return n == 0 ? 0 : sum / n;
    }

    out.add(FoodStoolLink(
      tag: e.key,
      daysEaten: eaten.length,
      diarrheaRateEaten: rate(eatenDays, (s) => s.isDiarrhea),
      bloodRateEaten: rate(eatenDays, (s) => s.hasBlood),
      avgCountEaten: avgCount(eatenDays),
      diarrheaRateBase: rate(baseDays, (s) => s.isDiarrhea),
      bloodRateBase: rate(baseDays, (s) => s.hasBlood),
      avgCountBase: avgCount(baseDays),
    ));
  }
  out.sort((a, b) {
    final da = (a.diarrheaRateEaten - a.diarrheaRateBase).abs() +
        (a.bloodRateEaten - a.bloodRateBase).abs();
    final db = (b.diarrheaRateEaten - b.diarrheaRateBase).abs() +
        (b.bloodRateEaten - b.bloodRateBase).abs();
    return db.compareTo(da);
  });
  return out;
}
