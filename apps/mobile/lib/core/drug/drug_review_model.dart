/// D2：药物评价模型与匿名上传白名单（不含病历）。
library;

class DrugReview {
  const DrugReview({
    required this.drugName,
    required this.ibdType,
    required this.efficacy,
    required this.seSideEffect,
    this.sideEffectTypes = const [],
    this.stillUsing = true,
    this.comment,
  });

  final String drugName;

  /// CD / UC / unknown
  final String ibdType;

  /// 1–5 星
  final int efficacy;

  /// 0=无 1=轻 2=中 3=重
  final int seSideEffect;
  final List<String> sideEffectTypes;
  final bool stillUsing;
  final String? comment;
}

/// 允许上云的字段白名单（D2.5）。
const kDrugReviewUploadKeys = {
  'drugName',
  'ibdType',
  'efficacy',
  'seSideEffect',
  'sideEffectTypes',
  'stillUsing',
  'comment',
};

const kSideEffectTypes = [
  '感染',
  '皮疹',
  '胃肠反应',
  '头痛',
  '肝酶升高',
  '其他',
];

/// 构造匿名上传 payload；断言无多余键。
Map<String, dynamic> drugReviewUploadPayload(DrugReview r) {
  final payload = <String, dynamic>{
    'drugName': r.drugName,
    'ibdType': r.ibdType,
    'efficacy': r.efficacy,
    'seSideEffect': r.seSideEffect,
    'sideEffectTypes': r.sideEffectTypes,
    'stillUsing': r.stillUsing,
  };
  if (r.comment != null && r.comment!.trim().isNotEmpty) {
    payload['comment'] = r.comment!.trim();
  }
  for (final k in payload.keys) {
    if (!kDrugReviewUploadKeys.contains(k)) {
      throw StateError('illegal upload key: $k');
    }
  }
  return payload;
}

class DrugReviewAggregate {
  const DrugReviewAggregate({
    required this.drugName,
    required this.avgEfficacy,
    required this.count,
    required this.seDist,
  });

  final String drugName;
  final double avgEfficacy;
  final int count;

  /// seSideEffect 0–3 → 条数
  final Map<int, int> seDist;
}

/// 本地聚合（无服务端时的「我的评价」统计）。
DrugReviewAggregate aggregateLocal(
  String drugName,
  List<DrugReview> all,
) {
  final rows = all.where((r) => r.drugName == drugName).toList();
  final n = rows.length;
  final avg =
      n == 0 ? 0.0 : rows.map((r) => r.efficacy).reduce((a, b) => a + b) / n;
  final dist = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};
  for (final r in rows) {
    dist[r.seSideEffect] = (dist[r.seSideEffect] ?? 0) + 1;
  }
  return DrugReviewAggregate(
    drugName: drugName,
    avgEfficacy: (avg * 10).round() / 10,
    count: n,
    seDist: dist,
  );
}
