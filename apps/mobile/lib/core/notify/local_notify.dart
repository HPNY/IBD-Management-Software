import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 远程推送 kind → 通用文案（禁止携带药品/剂量/病历）。
const Map<String, ({String title, String body})> kGenericPushCopy = {
  'medication': (title: 'IBDers', body: '您有一条用药提醒'),
  'injection': (title: 'IBDers', body: '您有一条注射提醒'),
  'followup': (title: 'IBDers', body: '您有一条复查提醒'),
  'system': (title: 'IBDers', body: '您有一条系统通知'),
};

/// 仅允许落地的通用短语白名单；其余远程文案一律丢弃并降级。
const Set<String> kAllowedRemoteCopy = {
  'IBDers',
  '您有一条用药提醒',
  '您有一条注射提醒',
  '您有一条复查提醒',
  '您有一条系统通知',
};

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
  /// - [title]/[body]：仅当命中 [kAllowedRemoteCopy] 时才采用；否则降级通用
  ///
  /// 不读取、不展示任何药品名/剂量/病历字段。
  Future<void> showRemoteAsLocal({
    String? kind,
    String? title,
    String? body,
  }) async {
    if (!_ready) await init();
    final generic =
        kGenericPushCopy[kind] ?? kGenericPushCopy['system']!;
    final safeTitle = (title != null && kAllowedRemoteCopy.contains(title))
        ? title
        : generic.title;
    final safeBody = (body != null && kAllowedRemoteCopy.contains(body))
        ? body
        : generic.body;
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      safeTitle,
      safeBody,
      const NotificationDetails(android: _remoteAndroid, iOS: DarwinNotificationDetails()),
    );
  }

  /// 按 kind 直接展示通用提醒（远程 payload 只带 kind 时使用）。
  Future<void> showGenericReminder(String kind) {
    return showRemoteAsLocal(kind: kind);
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
