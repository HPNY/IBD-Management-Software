import 'package:shared_preferences/shared_preferences.dart';

/// T4：提醒配置（通用结构，T6 的用药/复查提醒复用本模块）。
///
/// 当前实现注射提醒提前量集合；默认 `{3}` 与既有行为完全兼容
/// （未配置用户 = 提前 3 天）。持久化在 SharedPreferences，无 schema 变更。
class ReminderPrefs {
  static const _kInjectionLeads = 'ibd_reminder_injection_leads';

  /// 兼容默认：提前 3 天
  static const Set<int> defaultInjectionLeads = {3};

  /// 允许的提前量（天）：0 = 当天
  static const Set<int> allowedInjectionLeads = {0, 1, 2, 3, 7};

  /// 归一化：只保留允许值、去重升序；空结果回退默认（防止误清空）。
  static Set<int> normalizeLeads(Iterable<int> raw) {
    final v = raw.where(allowedInjectionLeads.contains).toSet();
    if (v.isEmpty) return defaultInjectionLeads;
    return (v.toList()..sort()).toSet();
  }

  static Future<Set<int>> loadInjectionLeads() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kInjectionLeads);
    if (raw == null) return defaultInjectionLeads;
    return normalizeLeads(
      raw.split(',').map((s) => int.tryParse(s.trim())).whereType<int>(),
    );
  }

  static Future<void> saveInjectionLeads(Iterable<int> leads) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kInjectionLeads, normalizeLeads(leads).join(','));
  }
}

/// 注射提醒触发时刻计算（纯函数，可单测）。
///
/// 每个提前量生成一条：计划日当天 9:00 减去提前天数；若该时刻已过，
/// 回落为 now + 1 分钟（沿用既有 `scheduleInjectionReminders` 语义）。
List<DateTime> injectionReminderFireTimes(
  DateTime planned,
  Set<int> leads, {
  DateTime? now,
}) {
  final anchor = now ?? DateTime.now();
  final effective = leads.isEmpty ? ReminderPrefs.defaultInjectionLeads : leads;
  final times = <DateTime>[];
  for (final lead in effective) {
    var fire = DateTime(planned.year, planned.month, planned.day, 9)
        .subtract(Duration(days: lead));
    if (fire.isBefore(anchor)) {
      fire = anchor.add(const Duration(minutes: 1));
    }
    times.add(fire);
  }
  return times;
}

/// 展示用：提前量集合 → 人读文案（如 "3 / 1 / 当天"）。
String formatInjectionLeads(Iterable<int> leads) {
  final sorted = leads.toList()..sort((a, b) => b.compareTo(a));
  return sorted
      .map((d) => d == 0 ? '当天' : '提前 $d 天')
      .join(' / ');
}
