import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_config.dart';
import '../api/push_api.dart';
import '../identity/local_identity.dart';
import '../notify/local_notify.dart';

/// 设备推送令牌来源。接入 firebase_messaging 后替换实现即可。
abstract class PushTokenSource {
  Future<String?> getToken();
  Future<void> deleteToken();
}

/// 默认令牌源：稳定本地占位串（dry-run / 未接 FCM SDK 时）。
/// 真机 FCM token 请实现 [PushTokenSource] 并在构造 [PushService] 时注入。
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
class PushService extends ChangeNotifier {
  PushService({
    required LocalIdentity identity,
    PushTokenSource? tokenSource,
    ApiConfig? config,
  })  : _identity = identity,
        _config = config ?? ApiConfig.dev() {
    _tokenSource = tokenSource ?? LocalPushTokenSource(identity.uuid);
  }

  final LocalIdentity _identity;
  final ApiConfig _config;
  late PushTokenSource _tokenSource;

  static const _kPushToken = 'ibd_push_token';
  bool _busy = false;
  String? _lastError;
  String? _registeredToken;

  bool get optIn => _identity.pushOptIn;
  bool get busy => _busy;
  String? get lastError => _lastError;
  String? get registeredTokenPrefix => _registeredToken?.substring(0, 12);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _registeredToken = sp.getString(_kPushToken);
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
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kPushToken, token);
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
          // 网络失败仍本地关闭；下次 enable 会覆盖
          _lastError = '注销请求失败（已在本机关闭）：$e';
        }
      }
      await _tokenSource.deleteToken();
      await _identity.setPushOptIn(false);
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_kPushToken);
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
