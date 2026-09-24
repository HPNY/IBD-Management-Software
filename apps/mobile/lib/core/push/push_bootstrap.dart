import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../identity/local_identity.dart';
import 'fcm_push_token_source.dart';
import 'push_service.dart';

/// 后台消息处理器（必须 top-level / static）。
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  // 仅记录 kind；落地为本地通知由前台/启动后 onRemoteMessage 处理
  debugPrint('FCM background message: ${message.messageId}');
}

/// 创建推送服务：优先 FCM，失败回落本地占位令牌（dry-run）。
Future<PushService> createPushService({
  required LocalIdentity identity,
}) async {
  PushTokenSource source;
  final fcmOk = await tryInitFcm();
  if (fcmOk) {
    source = FcmPushTokenSource();
    try {
      // 返回 void，不可 await；失败时仅打日志
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
    } catch (e) {
      debugPrint('FCM background handler register failed: $e');
    }
  } else {
    source = LocalPushTokenSource(identity.uuid);
    debugPrint('Push: using LocalPushTokenSource (no Firebase config)');
  }
  return PushService(identity: identity, tokenSource: source);
}
