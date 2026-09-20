/// 将解析管线返回的检验项规范为本地录入/入库结构。
Map<String, dynamic> normalizeParseLabItem(Map<dynamic, dynamic> raw) {
  final nameNorm = _str(raw['nameNorm']) ??
      _str(raw['name_norm']) ??
      _str(raw['name']) ??
      '';
  final nameRaw = _str(raw['nameRaw']) ??
      _str(raw['name_raw']) ??
      _str(raw['alias']) ??
      nameNorm;
  final valueNum = raw['value'] is num
      ? (raw['value'] as num).toDouble()
      : double.tryParse('${raw['value'] ?? ''}'.trim());
  final unit = _str(raw['unit']) ?? '';
  final refMin = _num(raw['refMin'] ?? raw['ref_min']);
  final refMax = _num(raw['refMax'] ?? raw['ref_max']);
  return {
    'nameNorm': nameNorm,
    'nameRaw': nameRaw,
    'value': valueNum,
    'valueText': valueNum == null ? '' : _fmt(valueNum),
    'unit': unit,
    'refMin': refMin,
    'refMax': refMax,
  };
}

List<Map<String, dynamic>> normalizeParseLabItems(List<dynamic> raw) {
  return raw
      .whereType<Map>()
      .map(normalizeParseLabItem)
      .where((e) => (e['nameNorm'] as String).isNotEmpty)
      .toList();
}

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

double? _num(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim());
}

String _fmt(double v) {
  if (v == v.roundToDouble() && !v.isNaN && v.abs() < 1e15) {
    return v.toInt().toString();
  }
  return '$v';
}
