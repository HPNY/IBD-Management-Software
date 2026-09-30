/// SF-36 标准 8 维计分（G7 · 并行：保留简化合计，另出域分）。
///
/// 选项已统一「分越高越好」(0–4)，无需反向计分。
/// 域分 = round(100 * sum(item) / (4 * n))，0–100。
library;

/// 域中文名（UI 用）。
const sf36DomainLabels = <String, String>{
  'gh': '一般健康',
  'pf': '生理功能',
  'rp': '生理职能',
  'bp': '躯体疼痛',
  'vt': '精力',
  'sf': '社会功能',
  're': '情感职能',
  'mh': '精神健康',
};

class Sf36Domains {
  Sf36Domains._();

  /// 「与一年前相比」变化题，不计入任何域。
  static const int changeItemIndex = 1;

  /// 固定题索引映射（0-based，对齐 `SurveyKit.sf36Questions` 顺序）。
  static const Map<String, List<int>> byId = {
    'gh': [0],
    'pf': [2, 3, 4, 5, 6, 7, 8, 9],
    'rp': [10, 11, 12, 34, 35],
    'bp': [18, 19],
    'vt': [20, 22, 25, 26],
    'sf': [16, 17, 23, 29, 31],
    're': [13, 14, 15, 28, 33],
    'mh': [21, 24, 27, 30, 32],
  };
}

class Sf36DomainResult {
  const Sf36DomainResult({required this.domains, required this.stdAverage});

  /// 域 id → 0–100。
  final Map<String, int> domains;

  /// 8 维算术均四舍五入（非 PCS/MCS）。
  final int stdAverage;
}

class Sf36Scoring {
  Sf36Scoring._();

  /// 单域 0–100；`scores` 长度须覆盖该域最大索引。
  static int scoreDomain(String domainId, List<int> scores) {
    final indices = Sf36Domains.byId[domainId];
    if (indices == null || indices.isEmpty) {
      throw ArgumentError('unknown SF-36 domain: $domainId');
    }
    var sum = 0;
    for (final i in indices) {
      if (i < 0 || i >= scores.length) {
        throw ArgumentError(
          'SF-36 item index $i out of range (len=${scores.length})',
        );
      }
      sum += scores[i];
    }
    return (100 * sum / (4 * indices.length)).round();
  }

  static Sf36DomainResult scoreAll(List<int> scores) {
    final domains = <String, int>{};
    for (final id in Sf36Domains.byId.keys) {
      domains[id] = scoreDomain(id, scores);
    }
    final sum = domains.values.fold<int>(0, (a, b) => a + b);
    return Sf36DomainResult(
      domains: domains,
      stdAverage: (sum / domains.length).round(),
    );
  }

  /// 简化合计：全部 36 题 0–4 之和（含变化题，兼容旧历史）。
  static int simplifiedTotal(List<int> scores) {
    if (scores.length != 36) {
      throw ArgumentError('SF-36 expects 36 answers, got ${scores.length}');
    }
    return scores.fold<int>(0, (a, b) => a + b);
  }
}
