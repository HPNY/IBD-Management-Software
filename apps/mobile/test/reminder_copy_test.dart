import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/notify/reminder_copy.dart';

/// T6：提醒文案脱敏固化（约束 §6：通知不含药名/剂量/病历字段）。
void main() {
  const allCopy = [
    kInjectionReminderBody,
    kInjectionTodayBody,
    kMedicationReminderBody,
    kFollowupReminderBody,
  ];

  const allTitles = [
    kMedicationReminderTitle,
    kFollowupReminderTitle,
  ];

  test('通知文案不含药名/剂量/检验等敏感词', () {
    const banned = [
      '乌帕替尼',
      '修美乐',
      '安健宁',
      '类克',
      '喜达诺',
      '安吉优',
      '喜开悦',
      '乌司奴',
      '利生奇珠',
      '英夫利昔',
      '阿达木',
      'mg',
      'g/L',
      'μg',
      '剂量',
      '血红蛋白',
      '钙卫蛋白',
      'CRP',
    ];
    for (final text in allCopy) {
      for (final word in banned) {
        expect(text.contains(word), isFalse,
            reason: '「$text」不应包含敏感词「$word」');
      }
    }
  });

  test('提醒正文为通用指引语（含 App 指引或遵医嘱）', () {
    for (final text in allCopy) {
      expect(text.contains('IBDers') || text.contains('医嘱'), isTrue,
          reason: '「$text」应为通用指引语');
    }
  });

  test('标题不含敏感词', () {
    expect(allTitles.join(), isNot(contains('药名')));
  });
}
