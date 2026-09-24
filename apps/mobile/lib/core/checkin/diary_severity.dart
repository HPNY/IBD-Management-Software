/// 打卡日历热力严重度（G2）：纯函数，0–10。
///
/// severity = clamp(pain*0.5 + min(bowel,10)*0.3 + bloodPts, 0..10)
/// bloodPts：none→0 · trace→1.5 · obvious→3（其余按 0）
double diarySeverity({
  int? painLevel,
  int? bowelCount,
  int? diarrheaCount,
  String? bloodyStool,
}) {
  final pain = (painLevel ?? 0).clamp(0, 10).toDouble();
  final bowel = (bowelCount ?? diarrheaCount ?? 0).clamp(0, 10).toDouble();
  var bloodPts = 0.0;
  switch (bloodyStool) {
    case 'trace':
      bloodPts = 1.5;
    case 'obvious':
      bloodPts = 3.0;
    case 'none':
    case null:
      bloodPts = 0.0;
    default:
      bloodPts = 0.0;
  }
  final raw = pain * 0.5 + bowel * 0.3 + bloodPts;
  return raw.clamp(0.0, 10.0);
}

/// 热力分档：null=无记录灰 · green · warning · danger（与 IbdColors 语义一致）。
String severityBand(double severity) {
  if (severity <= 3) return 'green';
  if (severity <= 6) return 'warning';
  return 'danger';
}
