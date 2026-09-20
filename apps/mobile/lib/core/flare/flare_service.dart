import '../db/repositories.dart';

enum FlareLevel { green, yellow, red }

class FlareResult {
  FlareResult({
    required this.level,
    required this.headline,
    required this.reasons,
    required this.advice,
  });

  final FlareLevel level;
  final String headline;
  final List<String> reasons;
  final String advice;
}

/// 发作预警（本地规则，PRD §2.7.3）。
class FlareService {
  FlareService({
    SymptomRepository? symptoms,
    BathroomRepository? bathroom,
    LabSeriesRepository? labs,
  })  : _symptoms = symptoms ?? SymptomRepository(),
        _bathroom = bathroom ?? BathroomRepository(),
        _labs = labs ?? LabSeriesRepository();

  final SymptomRepository _symptoms;
  final BathroomRepository _bathroom;
  final LabSeriesRepository _labs;

  Future<FlareResult> assess() async {
    final diaries = await _symptoms.listAll();
    final bath = await _bathroom.listAll();
    final reasons = <String>[];

    // RED：便血 / 剧痛
    final latestDiary = diaries.isNotEmpty ? diaries.first : null;
    final bloody =
        '${latestDiary?['bloody_stool'] ?? ''}' == 'obvious' ||
            '${latestDiary?['bloody_stool'] ?? ''}' == 'trace';
    final pain = (latestDiary?['pain_level'] as num?)?.toInt() ?? 0;
    // blood: 0=无 1=擦拭有 2=明显
    final bathBlood = bath.isNotEmpty &&
        ((bath.first['blood'] as num?)?.toInt() ?? 0) >= 1;

    if (bloody || bathBlood) {
      reasons.add('出现便血（日记/排便）');
    }
    if (pain >= 8) {
      reasons.add('腹痛 ≥8 分');
    }
    if (reasons.isNotEmpty) {
      return FlareResult(
        level: FlareLevel.red,
        headline: '警告 · 建议尽快就医',
        reasons: reasons,
        advice: '请携带就诊摘要与检验数据，按需急诊/门诊。本应用不替代医生。',
      );
    }

    // YELLOW：连续 3 天恶化或腹泻突增
    if (diaries.length >= 3) {
      final pains = diaries.take(3).map((d) => (d['pain_level'] as num?)?.toInt() ?? 0).toList();
      final diarrhea =
          diaries.take(3).map((d) => (d['diarrhea_count'] as num?)?.toInt() ?? 0).toList();
      // 时间倒序：oldest of 3 is index 2
      final painWorse = pains[0] > pains[1] && pains[1] > pains[2];
      final diarWorse = diarrhea[0] > diarrhea[1] && diarrhea[1] > diarrhea[2];
      final surge = diarrhea[0] >= 6 && diarrhea[0] > (diarrhea[2] + 2);
      if (painWorse) reasons.add('腹痛连续 3 天加重');
      if (diarWorse || surge) reasons.add('腹泻次数连续升高或突增');
    }
    if (diaries.isEmpty) {
      reasons.add('尚无症状打卡，无法评估趋势');
      return FlareResult(
        level: FlareLevel.yellow,
        headline: '关注 · 数据不足',
        reasons: reasons,
        advice: '连续记录 3 天症状与排便后再看预警。',
      );
    }
    if (reasons.isNotEmpty) {
      final crp = await _labs.seriesByName('超敏C反应蛋白');
      final cal = await _labs.seriesByName('粪便钙卫蛋白');
      if (crp.isNotEmpty || cal.isNotEmpty) {
        reasons.add(
          '近期检验：${crp.isNotEmpty ? 'CRP=${crp.last['value']}' : '—'}'
          '${cal.isNotEmpty ? ' 钙卫蛋白=${cal.last['value']}' : ''}',
        );
      }
      return FlareResult(
        level: FlareLevel.yellow,
        headline: '关注 · 建议近期复查',
        reasons: reasons,
        advice: '建议复查 CRP + 粪便钙卫蛋白；记录用药是否漏服。',
      );
    }

    return FlareResult(
      level: FlareLevel.green,
      headline: '正常 · 继续观察',
      reasons: const ['近期症状相对稳定'],
      advice: '保持打卡与用药；异常变化再打开本页。',
    );
  }
}
