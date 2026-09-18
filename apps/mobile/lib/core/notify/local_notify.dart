import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 本地注射提醒（不依赖服务端推送）。
class LocalNotifyService {
  LocalNotifyService._();
  static final LocalNotifyService instance = LocalNotifyService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

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
      '系统通知已启用（本地；FCM 可后续接入）',
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

  Future<void> scheduleInjectionReminders(
    List<Map<String, dynamic>> pending, {
    int leadDays = 3,
  }) async {
    if (!_ready) await init();
    await _plugin.cancelAll();
    var n = 0;
    for (final row in pending) {
      final planned = DateTime.tryParse('${row['planned_date']}');
      if (planned == null) continue;
      // 提前 leadDays 上午 9:00；若已过则当天 9:00 或 +1 分钟
      var fire = DateTime(planned.year, planned.month, planned.day, 9)
          .subtract(Duration(days: leadDays));
      if (fire.isBefore(DateTime.now())) {
        fire = DateTime.now().add(const Duration(minutes: 1));
      }
      await _plugin.zonedSchedule(
        1000 + n++,
        '注射提醒',
        '请准备 ${row['drug']}（${row['dose']}）· 计划 ${row['planned_date']}',
        tz.TZDateTime.from(fire, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ibd_injection',
            '注射提醒',
            channelDescription: '生物制剂注射排期提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
