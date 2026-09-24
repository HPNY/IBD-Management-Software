import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_service.dart';

/// 基于 `firebase_messaging` 的真机 FCM 令牌源。
///
/// 仅在 [tryInitFcm] 成功后注入；失败时请回落 [LocalPushTokenSource]，
/// 以免破坏无 Firebase 密钥构建的可用性。
class FcmPushTokenSource implements PushTokenSource {
  FcmPushTokenSource();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      return token;
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('FCM deleteToken failed: $e');
    }
  }

  /// 请求通知权限（iOS 必需；Android 13+ 也建议调用）。
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('FCM requestPermission failed: $e');
      return false;
    }
  }

  /// 订阅 token 刷新，变化时回调（用于重新上报）。
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}

/// 尝试初始化 Firebase Messaging。
///
/// 返回 true 表示可用 [FcmPushTokenSource]；false 表示无密钥/无配置，
/// 应使用 [LocalPushTokenSource]（dry-run / 本地通知保底）。
///
/// 可选环境变量（`--dart-define`）：
/// - `IBD_FIREBASE_PROJECT_ID` / `IBD_FIREBASE_APP_ID` / `IBD_FIREBASE_API_KEY`
///   提供后使用手动 [FirebaseOptions]，不依赖 `google-services.json`。
Future<bool> tryInitFcm() async {
  try {
    // 已有 google-services.json / GoogleService-Info.plist 时
    // Firebase.initializeApp() 可无参初始化。
    await Firebase.initializeApp();
  } catch (_) {
    const projectId = String.fromEnvironment('IBD_FIREBASE_PROJECT_ID');
    const appId = String.fromEnvironment('IBD_FIREBASE_APP_ID');
    const apiKey = String.fromEnvironment('IBD_FIREBASE_API_KEY');
    if (projectId.isEmpty || appId.isEmpty || apiKey.isEmpty) {
      return false;
    }
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId:
              String.fromEnvironment('IBD_FIREBASE_SENDER_ID'),
          projectId: projectId,
        ),
      );
    } catch (e) {
      debugPrint('FCM init (manual options) failed: $e');
      return false;
    }
  }
  try {
    // 探活：不支持 FCM 的平台视为不可用
    final supported = await Future.value(FirebaseMessaging.instance.isSupported());
    return supported;
  } catch (e) {
    debugPrint('FCM not usable: $e');
    return false;
  }
}
