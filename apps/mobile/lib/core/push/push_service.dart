import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../api/api_config.dart';
import '../api/push_api.dart';
import '../identity/local_identity.dart';
import '../notify/local_notify.dart';
import 'push_token_store.dart';

/// 设备推送令牌来源。
///
/// 真机 FCM：在 App 启动后注入基于 `firebase_messaging` 的实现，例如：
/// ```dart
/// class FcmPushTokenSource implements PushTokenSource {
///   Future<String?> getToken() async {
///     // await Firebase.initializeApp(...);
///     // return FirebaseMessaging.instance.getToken();
///   }
///   Future<void> deleteToken() async {
///     // await FirebaseMessaging.instance.deleteToken();
///   }
/// }
/// ```
/// 收到远程消息时调用 [PushService.onRemoteMessage] 落地为本地通知。
/// 未配置 Firebase 工程前请勿引入 firebase_messaging，以免破坏无密钥构建。
abstract class PushTokenSource {
  Future<String?> getToken();
  Future<void> deleteToken();
}

/// 默认令牌源：稳定本地占位串（dry-run / 未接 FCM SDK 时）。
class LocalPushTokenSource implements PushTokenSource {
  LocalPushTokenSource(this.appUserId);

  final String appUserId;
  static const _prefix = 'local-';

  @override
  Future<String?> getToken() async {
    final digest = sha256.convert(utf8.encode('ibd-push:$appUserId'));
    return '$_prefix${digest.toString().substring(0, 40)}';
  }

  @override
  Future<void> deleteToken() async {
    // 本地占位令牌无远端 SDK 状态可清
  }
}

/// 系统推送（远程 opt-in）：注册/注销设备令牌；落地走本地通知。
///
/// - 默认关闭；与登录无关，令牌只绑 app_user_uuid
/// - 可随时注销；不把推送做成登录门禁
/// - 令牌存 [PushTokenStore]（secure storage）
class PushService extends ChangeNotifier {
  PushService({
    required LocalIdentity identity,
    PushTokenSource? tokenSource,
    ApiConfig? config,
    PushTokenStore? tokenStore,
  })  : _identity = identity,
        _config = config ?? ApiConfig.dev(),
        _tokenStore = tokenStore ?? PushTokenStore() {
    _tokenSource = tokenSource ?? LocalPushTokenSource(identity.uuid);
  }

  final LocalIdentity _identity;
  final ApiConfig _config;
  final PushTokenStore _tokenStore;
  late PushTokenSource _tokenSource;

  bool _busy = false;
  String? _lastError;
  String? _registeredToken;

  bool get optIn => _identity.pushOptIn;
  bool get busy => _busy;
  String? get lastError => _lastError;
  String? get registeredTokenPrefix {
    final t = _registeredToken;
    if (t == null || t.isEmpty) return null;
    return t.length <= 12 ? t : t.substring(0, 12);
  }

  Future<void> load() async {
    _registeredToken = await _tokenStore.read();
    notifyListeners();
  }

  /// 开启远程推送：取令牌 → push-session → 注册。失败不改 optIn。
  Future<bool> enable() async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final token = await _tokenSource.getToken();
      if (token == null || token.isEmpty) {
        _lastError = '暂无法获取推送令牌';
        return false;
      }
      final api = PushApi(_config);
      final session = await api.pushSession(_identity.uuid);
      await api.registerDevice(
        token: token,
        appUserId: _identity.uuid,
        accessToken: session['accessToken'] as String,
        platform: defaultTargetPlatform.name,
      );
      await _identity.setPushOptIn(true);
      await _tokenStore.write(token);
      _registeredToken = token;
      return true;
    } catch (e) {
      _lastError = '$e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// 关闭并注销设备令牌（可随时调用）。
  /// 返回是否已在**本机**关闭；若远端注销失败会写入 [lastError]（本地仍关闭）。
  Future<bool> disable({bool unregisterRemote = true}) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final token = _registeredToken;
      if (unregisterRemote) {
        try {
          final api = PushApi(_config);
          final session = await api.pushSession(_identity.uuid);
          await api.unregisterDevice(
            appUserId: _identity.uuid,
            accessToken: session['accessToken'] as String,
            token: token,
          );
        } catch (e) {
          _lastError = '云端注销未完成（本机已关闭）：$e';
        }
      }
      await _tokenSource.deleteToken();
      await _identity.setPushOptIn(false);
      await _tokenStore.clear();
      _registeredToken = null;
      return true;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// 远程消息落地：只认 kind / 白名单通用文案。
  Future<void> onRemoteMessage({
    String? kind,
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) {
    return LocalNotifyService.instance.showRemoteAsLocal(
      kind: kind ?? (data?['kind'] as String?),
      title: title,
      body: body,
    );
  }

  /// 测试一条通用提醒（服务端 dry-run 或真实 FCM）。
  Future<String> testRemotePing() async {
    final api = PushApi(_config);
    final session = await api.pushSession(_identity.uuid);
    final res = await api.notifyGeneric(
      appUserId: _identity.uuid,
      accessToken: session['accessToken'] as String,
      kind: 'system',
    );
    final dryRun = res['dryRun'] == true;
    return dryRun
        ? '服务端 dry-run（未配置 FCM_*）：已模拟发送通用提醒'
        : '已请求 FCM 发送通用提醒（targets=${res['targets']}）';
  }
}
