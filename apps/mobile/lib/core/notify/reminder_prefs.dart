import 'dart:convert';

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

  // ---- T6：用药 / 复查提醒配置（复用本模块，T4 裁决⑤）----

  static const _kMedicationEnabled = 'ibd_reminder_medication_enabled';
  static const _kMedicationHour = 'ibd_reminder_medication_hour';
  static const _kFollowups = 'ibd_reminder_followups';

  /// 用药提醒默认关（存量行为无用药提醒，不改变默认体验）
  static Future<bool> loadMedicationEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kMedicationEnabled) ?? false;
  }

  static Future<void> saveMedicationEnabled(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kMedicationEnabled, enabled);
  }

  /// 用药提醒时刻（小时 0-23），默认 9 点
  static Future<int> loadMedicationHour() async {
    final sp = await SharedPreferences.getInstance();
    return normalizeHour(sp.getInt(_kMedicationHour));
  }

  static Future<void> saveMedicationHour(int hour) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kMedicationHour, normalizeHour(hour));
  }

  static int normalizeHour(int? raw) =>
      (raw == null || raw < 0 || raw > 23) ? 9 : raw;

  /// 复查/自定义提醒条目：{id, date: 'YYYY-MM-DD', hour: 0-23}
  static Future<List<Map<String, dynamic>>> loadFollowups() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kFollowups);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where(_validFollowup)
          .toList();
    } catch (_) {
      return []; // 损坏配置安全回退
    }
  }

  static Future<void> saveFollowups(List<Map<String, dynamic>> entries) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kFollowups, jsonEncode(entries.where(_validFollowup).toList()));
  }

  static bool _validFollowup(Map<String, dynamic> e) {
    final date = '${e['date'] ?? ''}';
    return e['id'] != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date);
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

/// T6：用药每日提醒锚点（纯函数）——下一次 hour:00（今日已过则明日）。
DateTime medicationDailyAnchor(DateTime now, int hour) {
  final h = ReminderPrefs.normalizeHour(hour);
  final today = DateTime(now.year, now.month, now.day, h);
  return today.isAfter(now) ? today : today.add(const Duration(days: 1));
}

/// T6：复查/自定义提醒时刻（纯函数）——按条目 date+hour；已过期条目跳过。
List<DateTime> followupFireTimes(
  List<Map<String, dynamic>> entries, {
  DateTime? now,
}) {
  final anchor = now ?? DateTime.now();
  final times = <DateTime>[];
  for (final e in entries) {
    final date = DateTime.tryParse('${e['date']}');
    if (date == null) continue;
    final h = ReminderPrefs.normalizeHour(
      e['hour'] is num ? (e['hour'] as num).toInt() : null,
    );
    final fire = DateTime(date.year, date.month, date.day, h);
    if (!fire.isAfter(anchor)) continue;
    times.add(fire);
  }
  return times;
}
