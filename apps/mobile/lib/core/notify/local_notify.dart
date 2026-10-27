import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'push_copy.dart';
import 'reminder_copy.dart';
import 'reminder_prefs.dart';

/// 本地通知（不依赖服务端推送）+ 远程推送落地为本地通知。
///
/// 隐私边界：
/// - 本地注射提醒可在本机生成（含药品细节，仅本机展示）
/// - 远程推送只允许通用文案；落地前做白名单过滤，绝不透传病历
class LocalNotifyService {
  LocalNotifyService._();
  static final LocalNotifyService instance = LocalNotifyService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const AndroidNotificationDetails _remoteAndroid =
      AndroidNotificationDetails(
    'ibd_remote',
    '系统推送',
    channelDescription: '远程提醒落地（仅通用文案）',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  /// 测试系统通知（验证权限与渠道）
  Future<void> showTestNotification() async {
    if (!_ready) await init();
    await _plugin.show(
      1,
      'IBDers',
      '系统通知已启用（本地优先；远程推送可选）',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ibd_system',
          '系统通知',
          channelDescription: 'IBDers 系统级通知测试',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// 远程推送落地为本地通知。
  ///
  /// - [kind]：medication | injection | followup | system，映射通用文案
  /// - [title]/[body]：仅当命中白名单时才采用；否则降级通用
  ///
  /// 不读取、不展示任何药品名/剂量/病历字段。
  Future<void> showRemoteAsLocal({
    String? kind,
    String? title,
    String? body,
  }) async {
    if (!_ready) await init();
    final safe = resolveRemoteCopy(kind: kind, title: title, body: body);
    await _plugin.show(
      DateTime.now().microsecondsSinceEpoch.remainder(0x7fffffff),
      safe.title,
      safe.body,
      const NotificationDetails(android: _remoteAndroid, iOS: DarwinNotificationDetails()),
    );
  }

  /// 按 kind 直接展示通用提醒（远程 payload 只带 kind 时使用）。
  Future<void> showGenericReminder(String kind) {
    return showRemoteAsLocal(kind: kind);
  }

  /// T6：一次性重排全部提醒（注射 + 用药 + 复查/自定义）。
  /// 先 cancelAll 再按类调度，避免互相清掉。
  /// 文案全部走 `reminder_copy` 通用语（不含药名/剂量/病历字段）。
  Future<void> rescheduleAll({
    List<Map<String, dynamic>> injections = const [],
    Set<int> injectionLeads = ReminderPrefs.defaultInjectionLeads,
    List<Map<String, dynamic>> medications = const [],
    int medicationHour = 9,
    List<Map<String, dynamic>> followups = const [],
  }) async {
    if (!_ready) await init();
    await _plugin.cancelAll();
    var n = 0;
    // 注射（id 1000+）：每个提前量一条；lead=0 用当天证件文案
    for (final row in injections) {
      final planned = DateTime.tryParse('${row['planned_date']}');
      if (planned == null) continue;
      for (final lead in injectionLeads.isEmpty
          ? ReminderPrefs.defaultInjectionLeads
          : injectionLeads) {
        final fire =
            injectionReminderFireTimes(planned, {lead}).first;
        await _zoned(
          1000 + n++,
          '注射提醒',
          lead == 0 ? kInjectionTodayBody : kInjectionReminderBody,
          fire,
        );
      }
    }
    // 用药（id 2000+）：每个在用药物一条每日重复（默认关，由配置开启）
    if (medications.isNotEmpty) {
      final anchor = medicationDailyAnchor(DateTime.now(), medicationHour);
      for (var i = 0; i < medications.length; i++) {
        await _zoned(
          2000 + i,
          kMedicationReminderTitle,
          kMedicationReminderBody,
          anchor,
          daily: true,
        );
      }
    }
    // 复查/自定义（id 3000+）：一次性提醒，过期条目自然跳过
    final times = followupFireTimes(followups);
    for (var i = 0; i < times.length; i++) {
      await _zoned(
        3000 + i,
        kFollowupReminderTitle,
        kFollowupReminderBody,
        times[i],
      );
    }
  }

  Future<void> _zoned(
    int id,
    String title,
    String body,
    DateTime fire, {
    bool daily = false,
  }) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(fire, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ibd_injection',
          '注射与用药提醒',
          channelDescription: '生物制剂注射/用药/复查排期提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: daily ? DateTimeComponents.time : null,
    );
  }
}
