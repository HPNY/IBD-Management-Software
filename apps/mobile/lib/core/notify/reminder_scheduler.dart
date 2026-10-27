import '../db/repositories.dart';
import 'local_notify.dart';
import 'reminder_prefs.dart';

/// T6：统一提醒调度入口。
///
/// 读取配置（T4 ReminderPrefs）与本机数据，一次性重排三类提醒：
/// 注射（提前量集合，lead=0 当天证件文案）/ 用药（每日重复，默认关）/
/// 复查自定义（一次性）。所有通知文案为通用语（`reminder_copy`），
/// 不含药名/剂量/病历字段。配置或排期变更后调用本入口即可。
class ReminderScheduler {
  static Future<void> syncAll() async {
    final leads = await ReminderPrefs.loadInjectionLeads();
    final medEnabled = await ReminderPrefs.loadMedicationEnabled();
    final medHour = await ReminderPrefs.loadMedicationHour();
    final followups = await ReminderPrefs.loadFollowups();
    final injections = await InjectionRepository().listPending(withinDays: 120);
    final medications = medEnabled
        ? (await MedicationRepository().listCurrent())
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
        : const <Map<String, dynamic>>[];
    await LocalNotifyService.instance.rescheduleAll(
      injections: injections,
      injectionLeads: leads,
      medications: medications,
      medicationHour: medHour,
      followups: followups,
    );
  }
}
