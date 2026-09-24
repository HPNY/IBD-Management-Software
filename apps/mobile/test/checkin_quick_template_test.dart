import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/checkin/quick_template.dart';

void main() {
  Map<String, dynamic> fullYesterday() => {
        'pain_level': 7,
        'diarrhea_count': 3,
        'stool_type': 6,
        'bowel_count': 5,
        'bloody_stool': 'trace',
        'urgency': 1,
        'mucus': 0,
        'nausea': 1,
        'fatigue': 4,
        'oral_ulcer': 1,
        'joint_pain': 1,
        'joint_pain_site': '膝',
        'custom_items': '[{"label":"皮疹","value":"轻"}]',
        'sleep_hours': 6.5,
        'sleep_quality': 2,
        'sleep_insomnia': 1,
        'night_wakes': 2,
        'stress_level': 8,
        'stress_source': '工作',
      };

  test('和昨天一样：字段复制且 feeling=same', () {
    final m = prefilledFromYesterday(fullYesterday(), overallFeeling: 'same');
    expect(m['painLevel'], 7);
    expect(m['stoolType'], 6);
    expect(m['bowelCount'], 5);
    expect(m['bloodyStool'], 'trace');
    expect(m['urgency'], true);
    expect(m['oralUlcer'], true);
    expect(m['jointPainSite'], '膝');
    expect(m['sleepHours'], 6.5);
    expect(m['stressLevel'], 8);
    expect(m['overallFeeling'], 'same');
  });

  test('比昨天好/差：仅覆盖 feeling', () {
    final better = prefilledFromYesterday(
      fullYesterday(),
      overallFeeling: 'better',
    );
    final worse = prefilledFromYesterday(
      fullYesterday(),
      overallFeeling: 'worse',
    );
    expect(better['overallFeeling'], 'better');
    expect(worse['overallFeeling'], 'worse');
    expect(better['painLevel'], 7);
    expect(worse['painLevel'], 7);
  });

  test('旧数据缺新列：扩展字段给安全默认，不抛', () {
    final m = prefilledFromYesterday(
      {
        'pain_level': 2,
        'bloody_stool': '1', // 旧布尔/数字兼容
      },
      overallFeeling: 'same',
    );
    expect(m['painLevel'], 2);
    expect(m['bloodyStool'], 'obvious');
    expect(m['oralUlcer'], false);
    expect(m['sleepHours'], isNull);
    expect(m['stressLevel'], isNull);
    expect(m['overallFeeling'], 'same');
  });

  test('缺 bowel_count 回落 diarrhea_count', () {
    final m = prefilledFromYesterday(
      {'diarrhea_count': 4},
      overallFeeling: 'same',
    );
    expect(m['bowelCount'], 4);
  });
}
