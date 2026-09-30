/// D4：AI/规则辅助分析纯函数（本地统计，非 ML；仅供参考）。
library;

enum TrendDirection { rising, stable, falling, unknown }

class MetricTrend {
  const MetricTrend({
    required this.name,
    required this.direction,
    required this.points,
    this.last,
    this.avg30,
    this.avg90,
  });

  final String name;
  final TrendDirection direction;
  final int points;
  final double? last;
  final double? avg30;
  final double? avg90;

  String get label => switch (direction) {
        TrendDirection.rising => '升高',
        TrendDirection.falling => '下降',
        TrendDirection.stable => '稳定',
        TrendDirection.unknown => '数据不足',
      };
}

class AiAlert {
  const AiAlert({
    required this.kind,
    required this.title,
    required this.detail,
    required this.severity,
  });

  /// lab_consecutive_up | blood_streak | stool_surge
  final String kind;
  final String title;
  final String detail;

  /// warn | info
  final String severity;
}

class MedDelta {
  const MedDelta({
    required this.drugName,
    required this.metric,
    required this.beforeAvg,
    required this.afterAvg,
    required this.beforeN,
    required this.afterN,
  });

  final String drugName;
  final String metric;
  final double beforeAvg;
  final double afterAvg;
  final int beforeN;
  final int afterN;

  double get changePct =>
      beforeAvg == 0 ? 0 : (afterAvg - beforeAvg) / beforeAvg * 100;
}

/// 近 N 点线性方向：末段 vs 首段均值；相对幅度 <10% 视为稳定。
TrendDirection trendDirection(List<double> values) {
  if (values.length < 3) return TrendDirection.unknown;
  final n = values.length;
  final window = n >= 6 ? 3 : (n ~/ 2).clamp(1, 3);
  double avg(Iterable<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
  final head = avg(values.take(window));
  final tail = avg(values.skip(n - window));
  if (head == 0) {
    return tail > 0 ? TrendDirection.rising : TrendDirection.stable;
  }
  final rel = (tail - head).abs() / head.abs();
  if (rel < 0.1) return TrendDirection.stable;
  return tail > head ? TrendDirection.rising : TrendDirection.falling;
}

/// 按日期升序的数值点 → 趋势摘要。
MetricTrend summarizeSeries({
  required String name,
  required List<double> values,
}) {
  final dir = trendDirection(values);
  double? avgLast(int n) {
    if (values.isEmpty) return null;
    final slice =
        values.length <= n ? values : values.sublist(values.length - n);
    return slice.reduce((a, b) => a + b) / slice.length;
  }

  return MetricTrend(
    name: name,
    direction: dir,
    points: values.length,
    last: values.isEmpty ? null : values.last,
    avg30: avgLast(30),
    avg90: avgLast(90),
  );
}

/// 连续两次升高（相邻三点 v0<v1<v2）→ 异常卡。
List<AiAlert> labConsecutiveRise({
  required String name,
  required List<double> values,
}) {
  final out = <AiAlert>[];
  if (values.length < 3) return out;
  final n = values.length;
  if (values[n - 1] > values[n - 2] && values[n - 2] > values[n - 3]) {
    out.add(AiAlert(
      kind: 'lab_consecutive_up',
      title: '$name 连续两次升高',
      detail:
          '最近三次：${values[n - 3].toStringAsFixed(1)} → ${values[n - 2].toStringAsFixed(1)} → ${values[n - 1].toStringAsFixed(1)}。建议就医评估。',
      severity: 'warn',
    ));
  }
  return out;
}

/// 便血连续 N 天（dates 升序 + flags）。
List<AiAlert> bloodStreak({
  required List<String> dates,
  required List<bool> hasBlood,
  int days = 2,
}) {
  final out = <AiAlert>[];
  if (dates.length < days || hasBlood.length != dates.length) return out;
  final n = dates.length;
  var streak = 0;
  for (var i = n - 1; i >= 0; i--) {
    if (hasBlood[i]) {
      streak++;
    } else {
      break;
    }
  }
  if (streak >= days) {
    out.add(AiAlert(
      kind: 'blood_streak',
      title: '便血连续 $streak 天',
      detail: '从 ${dates[n - streak]} 至 ${dates[n - 1]}。建议尽快就医。',
      severity: 'warn',
    ));
  }
  return out;
}

/// 排便突增：今日次数 ≥ 且比近 7 日均值高 ≥3。
List<AiAlert> stoolSurge({
  required List<double> dailyCounts,
  double minToday = 6,
  double surgeDelta = 3,
}) {
  final out = <AiAlert>[];
  if (dailyCounts.length < 2) return out;
  final today = dailyCounts.last;
  final prior = dailyCounts.sublist(0, dailyCounts.length - 1);
  final baseWindow =
      prior.length <= 7 ? prior : prior.sublist(prior.length - 7);
  final base =
      baseWindow.reduce((a, b) => a + b) / (baseWindow.isEmpty ? 1 : baseWindow.length);
  if (today >= minToday && today - base >= surgeDelta) {
    out.add(AiAlert(
      kind: 'stool_surge',
      title: '排便次数突增',
      detail:
          '今日 $today 次 · 近 7 日均 ${base.toStringAsFixed(1)} 次。建议补水并评估是否就医。',
      severity: 'warn',
    ));
  }
  return out;
}

/// 用药前后同指标均值对比（start 之前 vs 当天起）。
/// [labs] 须按日期升序；[start] 为 start_date `yyyy-MM-dd`。
MedDelta? medBeforeAfter({
  required String drugName,
  required String metric,
  required List<String> labDates,
  required List<double> labValues,
  required String start,
}) {
  if (labDates.length != labValues.length || labDates.isEmpty) return null;
  final before = <double>[];
  final after = <double>[];
  for (var i = 0; i < labDates.length; i++) {
    if (labDates[i].compareTo(start) < 0) {
      before.add(labValues[i]);
    } else {
      after.add(labValues[i]);
    }
  }
  if (before.isEmpty || after.isEmpty) return null;
  double avg(List<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
  return MedDelta(
    drugName: drugName,
    metric: metric,
    beforeAvg: avg(before),
    afterAvg: avg(after),
    beforeN: before.length,
    afterN: after.length,
  );
}
