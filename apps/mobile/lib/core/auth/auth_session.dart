import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/api_config.dart';
import 'token_store.dart';

class AuthSession extends ChangeNotifier {
  AuthSession(this._config, this._store);

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
