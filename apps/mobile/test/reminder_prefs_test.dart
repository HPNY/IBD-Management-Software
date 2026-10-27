import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/notify/reminder_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T4：注射提醒提前量配置与调度时刻计算回归。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReminderPrefs', () {
    test('未配置时默认 {3}（兼容旧行为）', () async {
      expect(await ReminderPrefs.loadInjectionLeads(), ReminderPrefs.defaultInjectionLeads);
      expect(ReminderPrefs.defaultInjectionLeads, {3});
    });

    test('保存/读取往返（当天/1 天/7 天）', () async {
      await ReminderPrefs.saveInjectionLeads([7, 0, 1]);
      expect(await ReminderPrefs.loadInjectionLeads(), {0, 1, 7});
    });

    test('归一化：剔除非法值、去重、升序', () {
      expect(ReminderPrefs.normalizeLeads([3, 3, 9, 1, -2]), {1, 3});
    });

    test('空集合回退默认（防误清空）', () async {
      expect(ReminderPrefs.normalizeLeads([]), {3});
      await ReminderPrefs.saveInjectionLeads([]);
      expect(await ReminderPrefs.loadInjectionLeads(), {3});
    });

    test('损坏配置串回退默认', () async {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('ibd_reminder_injection_leads', 'x,y,zz');
      expect(await ReminderPrefs.loadInjectionLeads(), {3});
    });
  });

  group('injectionReminderFireTimes', () {
    final planned = DateTime(2026, 11, 10);
    final now = DateTime(2026, 11, 1, 8);

    test('默认提前 3 天：计划日 9:00 减 3 天', () {
      final times = injectionReminderFireTimes(planned, {3}, now: now);
      expect(times, [DateTime(2026, 11, 7, 9)]);
    });

    test('多提前量 {0,1,3}：三条且时刻正确', () {
      final times = injectionReminderFireTimes(planned, {3, 1, 0}, now: now);
      expect(times, [
        DateTime(2026, 11, 7, 9),
        DateTime(2026, 11, 9, 9),
        DateTime(2026, 11, 10, 9),
      ]);
    });

    test('已过时刻回落 now + 1 分钟', () {
      final lateNow = DateTime(2026, 11, 12, 12);
      final times = injectionReminderFireTimes(planned, {3, 0}, now: lateNow);
      expect(times, everyElement(DateTime(2026, 11, 12, 12, 1)));
    });

    test('空集合回退默认 {3}', () {
      final times = injectionReminderFireTimes(planned, {}, now: now);
      expect(times, [DateTime(2026, 11, 7, 9)]);
    });
  });
}
