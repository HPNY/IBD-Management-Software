/// 快捷模板（G2）：把昨日打卡预填到今日表单。只预填，不落库。
///
/// 返回可直接喂给表单 setState 的字段快照（camelCase，与页面状态一致）。
/// 昨日缺列时对应键不出现，由调用方保留今日默认值。
Map<String, Object?> prefilledFromYesterday(
  Map<String, dynamic> yesterday, {
  required String overallFeeling,
}) {
  Object? take(String dbKey) => yesterday[dbKey];

  final out = <String, Object?>{
    'painLevel': (take('pain_level') as num?)?.round() ?? 0,
    'diarrheaCount': (take('diarrhea_count') as num?)?.round() ?? 0,
    'stoolType': (take('stool_type') as num?)?.round() ?? 4,
    'bowelCount': (take('bowel_count') as num?)?.round() ??
        (take('diarrhea_count') as num?)?.round() ??
        0,
    'bloodyStool': _normalizeBlood(take('bloody_stool')),
    'urgency': take('urgency') == 1,
    'mucus': take('mucus') == 1,
    'nausea': take('nausea') == 1 || take('nausea') == true,
    'fatigueFlag': ((take('fatigue') as num?) ?? 0) > 0,
    'fatigue': (take('fatigue') as num?)?.round() ?? 0,
    'overallFeeling': overallFeeling,
    // G2/G4 扩展（昨日旧数据无列时给安全默认）
    'oralUlcer': take('oral_ulcer') == 1 || take('oral_ulcer') == true,
    'jointPain': take('joint_pain') == 1 || take('joint_pain') == true,
    'jointPainSite': '${take('joint_pain_site') ?? ''}',
    'customItemsJson': take('custom_items') as String?,
    'sleepHours': (take('sleep_hours') as num?)?.toDouble(),
    'sleepQuality': (take('sleep_quality') as num?)?.round(),
    'sleepInsomnia': take('sleep_insomnia') == 1,
    'nightWakes': (take('night_wakes') as num?)?.round() ?? 0,
    'stressLevel': (take('stress_level') as num?)?.round(),
    'stressSource': take('stress_source') as String?,
  };
  return out;
}

String? _normalizeBlood(Object? raw) {
  final s = '${raw ?? 'none'}';
  if (s == 'none' || s == 'trace' || s == 'obvious') return s;
  if (s == '1' || s == 'true') return 'obvious';
  return 'none';
}
