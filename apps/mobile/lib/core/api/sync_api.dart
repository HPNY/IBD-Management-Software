import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class SyncApi {
  SyncApi(this.config);

  final ApiConfig config;

  Future<Map<String, dynamic>> parseSession(String appUserId) async {
    final res = await http.post(
      config.uri('/api/v1/auth/parse-session'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'appUserId': appUserId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('parse-session ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> syncSession(String appUserId) async {
    final res = await http.post(
      config.uri('/api/v1/auth/sync-session'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'appUserId': appUserId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('sync-session ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<void> putCipher({
    required String token,
    required String appUserId,
    required String dataType,
    required String cipher,
    required String nonce,
    required String clientUpdatedAt,
    int? version,
  }) async {
    final res = await http.post(
      config.uri('/api/v1/sync/ciphertext'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'appUserId': appUserId,
        'dataType': dataType,
        'cipher': cipher,
        'nonce': nonce,
        'clientUpdatedAt': clientUpdatedAt,
        if (version != null) 'version': version,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('sync put ${res.statusCode} ${res.body}');
    }
  }

  Future<List<dynamic>> listCipher({
    required String token,
    required String appUserId,
  }) async {
    final res = await http.get(
      config.uri('/api/v1/sync/ciphertexts', {'appUserId': appUserId}),
      headers: {'authorization': 'Bearer $token'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('sync list ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
  }

  Future<void> wipe({
    required String token,
    required String appUserId,
  }) async {
    final res = await http.delete(
      config.uri('/api/v1/sync/ciphertexts', {'appUserId': appUserId}),
      headers: {'authorization': 'Bearer $token'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('sync wipe ${res.statusCode}');
    }
  }
}
