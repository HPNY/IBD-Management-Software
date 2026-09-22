import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/notify/push_copy.dart';

void main() {
  test('通用文案不含药品/剂量/病历字样', () {
    const forbidden = [
      '药名',
      '剂量',
      'mg',
      'ml',
      '阿达木',
      '乌帕',
      '诊断',
      '克罗恩',
      '溃疡性',
      '检验',
      'CRP',
      '医院',
    ];
    for (final e in kGenericPushCopy.entries) {
      final blob = '${e.value.title}${e.value.body}';
      expect(e.value.title, 'IBDers', reason: e.key);
      expect(e.value.body, startsWith('您有一条'), reason: e.key);
      for (final bad in forbidden) {
        expect(blob.contains(bad), isFalse, reason: '${e.key} leaks $bad');
      }
    }
    expect(kGenericPushCopy.keys, containsAll(['medication', 'injection', 'followup', 'system']));
  });

  test('白名单外的 title/body 一律降级为通用', () {
    final r = resolveRemoteCopy(
      kind: 'medication',
      title: '请服用乌帕替尼 15mg',
      body: '今日剂量 15mg，餐后',
    );
    expect(r.title, 'IBDers');
    expect(r.body, '您有一条用药提醒');
  });

  test('白名单内文案可通过', () {
    final r = resolveRemoteCopy(
      kind: 'injection',
      title: 'IBDers',
      body: '您有一条注射提醒',
    );
    expect(r.title, 'IBDers');
    expect(r.body, '您有一条注射提醒');
  });

  test('未知 kind 回落 system，且不接受任意 kind 映射', () {
    final r = resolveRemoteCopy(kind: 'evil');
    expect(r.title, 'IBDers');
    expect(r.body, '您有一条系统通知');
  });
}
