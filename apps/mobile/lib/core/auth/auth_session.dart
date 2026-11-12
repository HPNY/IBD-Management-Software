import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/api_config.dart';
import 'token_store.dart';

class AuthSession extends ChangeNotifier {
  AuthSession(this._config, this._store);

  /// 短时解析会话：仅内存 token，不持久化。
  factory AuthSession.parseSession(String accessToken, String appUserId) {
    final s = AuthSession(ApiConfig.dev(), TokenStore());
    s._tokens = AuthTokens(
      accessToken: accessToken,
      refreshToken: '',
      userId: appUserId,
    );
    return s;
  }

  /// 匿名只读会话：真正向 API 换取短时 token。
  ///
  /// P0-1：此前多处用 `parseSession('', uuid)` 造了空 token 的假会话，
  /// 请求头变成 `Bearer `，接口恒 401。要么换真 token，要么隐藏入口。
  static Future<AuthSession> mintParseSession(String appUserId) async {
    final config = ApiConfig.dev();
    final client = http.Client();
    try {
      final res = await client.post(
        config.uri('/api/v1/auth/parse-session'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'appUserId': appUserId}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(
          'parse-session failed: HTTP ${res.statusCode} '
          '${utf8.decode(res.bodyBytes, allowMalformed: true)}',
        );
      }
      final json =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final token = json['accessToken'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('parse-session returned empty token');
      }
      return AuthSession.parseSession(token, appUserId);
    } finally {
      client.close();
    }
  }

  final ApiConfig _config;
  final TokenStore _store;
  final http.Client _client = http.Client();

  AuthTokens? _tokens;
  AuthTokens? get tokens => _tokens;
  bool get isLoggedIn => _tokens != null;
  String? get accessToken => _tokens?.accessToken;

  Future<void> restore() async {
    _tokens = await _store.load();
    notifyListeners();
  }

  Future<void> login({
    required String phone,
    required String code,
    String? deviceId,
  }) async {
    final res = await _client.post(
      _config.uri('/api/v1/auth/login'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'code': code,
        if (deviceId != null) 'deviceId': deviceId,
      }),
    );
    _ensureOk(res, 'login');
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final user = json['user'] as Map<String, dynamic>;
    final next = AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      userId: user['id'] as String,
      phone: user['phone'] as String?,
    );
    await _store.save(next);
    _tokens = next;
    notifyListeners();
  }

  Future<bool> tryRefresh() async {
    final cur = _tokens;
    if (cur == null) return false;
    final res = await _client.post(
      _config.uri('/api/v1/auth/refresh'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'refreshToken': cur.refreshToken}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      await logout();
      return false;
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final user = json['user'] as Map<String, dynamic>;
    final next = AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      userId: user['id'] as String,
      phone: user['phone'] as String?,
    );
    await _store.save(next);
    _tokens = next;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    final refresh = _tokens?.refreshToken;
    if (refresh != null) {
      try {
        await _client.post(
          _config.uri('/api/v1/auth/logout'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'refreshToken': refresh}),
        );
      } catch (_) {
        // ignore network errors on logout
      }
    }
    await _store.clear();
    _tokens = null;
    notifyListeners();
  }

  Map<String, String> authHeaders([Map<String, String>? extra]) {
    final access = _tokens?.accessToken;
    return {
      if (access != null) 'authorization': 'Bearer $access',
      ...?extra,
    };
  }

  void _ensureOk(http.Response res, String op) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        '$op failed: HTTP ${res.statusCode} ${utf8.decode(res.bodyBytes, allowMalformed: true)}',
      );
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
