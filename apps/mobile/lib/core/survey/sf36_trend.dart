import 'dart:convert';

/// SF-36 域分历史序列（供量表页趋势展示；纯函数，无 Flutter 依赖）。

class Sf36TrendPoint {
  const Sf36TrendPoint({
    required this.date,
    required this.domains,
    required this.stdAverage,
  });

  final String date;
  final Map<String, int> domains;
  final int stdAverage;
}

/// 从 quality_surveys 行解析带 `domains` 的 SF-36 点，按日期升序。
///
/// 行需含 `date`、`kind`、`detail_json`（或已解码 `detail`）。
/// 无 domains 或非 SF36 的行跳过；解析失败跳过不抛。
List<Sf36TrendPoint> sf36TrendFromHistory(Iterable<Map<String, dynamic>> rows) {
  final out = <Sf36TrendPoint>[];
  for (final row in rows) {
    if ('${row['kind']}' != 'SF36') continue;
    final date = '${row['date'] ?? ''}';
    if (date.isEmpty) continue;
    final dynamic detailRaw = row['detail'];
    Map<String, dynamic>? detail;
    if (detailRaw is Map) {
      detail = Map<String, dynamic>.from(detailRaw);
    } else {
      final json = row['detail_json'];
      if (json is! String || json.isEmpty) continue;
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map) detail = Map<String, dynamic>.from(decoded);
      } catch (_) {
        continue;
      }
    }
    final domainsRaw = detail?['domains'];
    if (domainsRaw is! Map) continue;
    final domains = <String, int>{};
    for (final e in domainsRaw.entries) {
      final v = e.value;
      if (v is num) domains['${e.key}'] = v.round();
    }
    if (domains.isEmpty) continue;
    final avgRaw = detail?['stdAverage'];
    final avg = avgRaw is num
        ? avgRaw.round()
        : (domains.values.fold<int>(0, (a, b) => a + b) / domains.length).round();
    out.add(Sf36TrendPoint(date: date, domains: domains, stdAverage: avg));
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// 按域抽时间序列值（升序日期），缺该域的点跳过。
List<double> domainSeries(
  List<Sf36TrendPoint> points,
  String domainId, {
  int? maxPoints,
}) {
  final vals = <double>[
    for (final p in points)
      if (p.domains[domainId] != null) p.domains[domainId]!.toDouble(),
  ];
  if (maxPoints != null && vals.length > maxPoints) {
    return vals.sublist(vals.length - maxPoints);
  }
  return vals;
}

/// 对应日期标签（与 domainSeries 同步过滤）。
List<String> domainSeriesDates(
  List<Sf36TrendPoint> points,
  String domainId, {
  int? maxPoints,
}) {
  final ds = <String>[
    for (final p in points)
      if (p.domains[domainId] != null) p.date,
  ];
  if (maxPoints != null && ds.length > maxPoints) {
    return ds.sublist(ds.length - maxPoints);
  }
  return ds;
}
