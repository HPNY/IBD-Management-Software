import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// 设备令牌注册/注销（只绑 appUserId，无登录墙）。
class PushApi {
  PushApi(this.config);

  final ApiConfig config;

  Future<Map<String, dynamic>> pushSession(String appUserId) async {
    final res = await http.post(
      config.uri('/api/v1/auth/push-session'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'appUserId': appUserId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('push-session ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> registerDevice({
    required String token,
    required String appUserId,
    required String accessToken,
    String platform = 'android',
  }) async {
    final res = await http.post(
      config.uri('/api/v1/push/devices'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'appUserId': appUserId,
        'token': token,
        'platform': platform,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('push register ${res.statusCode} ${res.body}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// [token] 为空则注销该 appUserId 下全部令牌。
  Future<void> unregisterDevice({
    required String appUserId,
    required String accessToken,
    String? token,
  }) async {
    final query = {
      'appUserId': appUserId,
      if (token != null && token.isNotEmpty) 'token': token,
    };
    final res = await http.delete(
      config.uri('/api/v1/push/devices', query),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(query),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('push unregister ${res.statusCode}');
    }
  }

  /// 测试：请求服务端发一条通用提醒（服务端未配 FCM 时 dry-run）。
  Future<Map<String, dynamic>> notifyGeneric({
    required String appUserId,
    required String accessToken,
    String kind = 'system',
  }) async {
    final res = await http.post(
      config.uri('/api/v1/push/notify'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'appUserId': appUserId, 'kind': kind}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('push notify ${res.statusCode} ${res.body}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
