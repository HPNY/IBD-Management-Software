import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';
import 'api_config.dart';

class PresignResult {
  PresignResult({
    required this.objectKey,
    required this.uploadUrl,
    required this.method,
    required this.headers,
    required this.expiresAt,
    required this.driver,
  });

  final String objectKey;
  final String uploadUrl;
  final String method;
  final Map<String, String> headers;
  final String expiresAt;
  final String driver;

  factory PresignResult.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    return PresignResult(
      objectKey: json['objectKey'] as String,
      uploadUrl: json['uploadUrl'] as String,
      method: (json['method'] as String?) ?? 'PUT',
      headers: rawHeaders is Map
          ? rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()))
          : <String, String>{},
      expiresAt: (json['expiresAt'] as String?) ?? '',
      driver: (json['driver'] as String?) ?? 'local',
    );
  }
}

class ParseJobDto {
  ParseJobDto({
    required this.id,
    required this.status,
    required this.objectKey,
    this.items = const [],
    this.error,
  });

  final String id;
  final String status;
  final String objectKey;
  final List<dynamic> items;
  final String? error;

  factory ParseJobDto.fromJson(Map<String, dynamic> json) {
    return ParseJobDto(
      id: json['id'] as String,
      status: (json['status'] as String?) ?? 'queued',
      objectKey: (json['objectKey'] as String?) ?? '',
      items: (json['items'] as List?) ?? const [],
      error: json['error'] as String?,
    );
  }
}

class IbdApiException implements Exception {
  IbdApiException(this.message, {this.body, this.statusCode});

  final String message;
  final String? body;
  final int? statusCode;

  @override
  String toString() =>
      body == null || body!.isEmpty ? message : '$message\n$body';
}

/// 业务 API：自动附带 Bearer；401 时尝试 refresh 一次。
class IbdApiClient {
  IbdApiClient(this.config, this.session, {http.Client? client})
      : _client = client ?? http.Client();

  final ApiConfig config;
  final AuthSession session;
  final http.Client _client;

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    bool auth = true,
    bool isJsonBody = true,
  }) async {
    Future<http.Response> once() {
      final h = {
        if (isJsonBody && body != null) 'content-type': 'application/json',
        if (auth) ...session.authHeaders(),
        ...?headers,
      };
      final encoded = body == null
          ? null
          : (body is String ? body : jsonEncode(body));
      switch (method) {
        case 'GET':
          return _client.get(uri, headers: h);
        case 'POST':
          return _client.post(uri, headers: h, body: encoded);
        case 'PUT':
          return _client.put(uri, headers: h, body: encoded);
        default:
          throw ArgumentError('unsupported $method');
      }
    }

    var res = await once();
    if (res.statusCode == 401 && auth) {
      final ok = await session.tryRefresh();
      if (ok) res = await once();
    }
    return res;
  }

  void _ensureOk(http.Response res, String op) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw IbdApiException(
        '$op failed: HTTP ${res.statusCode}',
        body: utf8.decode(res.bodyBytes, allowMalformed: true),
        statusCode: res.statusCode,
      );
    }
  }

  Map<String, dynamic> _json(http.Response res) =>
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

  Future<List<dynamic>> listLabs() async {
    final res = await _send('GET', config.uri('/api/v1/labs'));
    _ensureOk(res, 'listLabs');
    return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createLab({
    required String date,
    String? hospital,
    required List<Map<String, dynamic>> items,
    String source = 'manual',
    String deviceId = 'mobile',
  }) async {
    final res = await _send(
      'POST',
      config.uri('/api/v1/labs'),
      body: {
        'date': date,
        if (hospital != null && hospital.isNotEmpty) 'hospital': hospital,
        'items': items,
        'source': source,
        'deviceId': deviceId,
      },
    );
    _ensureOk(res, 'createLab');
    return _json(res);
  }

  Future<PresignResult> presign({
    required String filename,
    String contentType = 'application/octet-stream',
    int expiresInSec = 900,
  }) async {
    final res = await _send(
      'POST',
      config.uri('/api/v1/files/presign'),
      body: {
        'filename': filename,
        'contentType': contentType,
        'expiresInSec': expiresInSec,
      },
    );
    _ensureOk(res, 'presign');
    return PresignResult.fromJson(_json(res));
  }

  Future<void> uploadBytes({
    required PresignResult presign,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final headers = {
      ...presign.headers,
      if (contentType != null) 'content-type': contentType,
    };
    final uri = Uri.parse(presign.uploadUrl);
    // 直传 URL 不带 JWT（local 用 HMAC；s3 用预签名）
    final streamed = http.Request(presign.method, uri)
      ..headers.addAll(headers)
      ..bodyBytes = bytes;
    final res = await _client.send(streamed);
    final body = await res.stream.bytesToString();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw IbdApiException('upload failed: HTTP ${res.statusCode}', body: body);
    }
  }

  Future<ParseJobDto> enqueueParse({
    required String objectKey,
    String? hospitalHint,
    String? reportType,
  }) async {
    final res = await _send(
      'POST',
      config.uri('/api/v1/parse/jobs'),
      body: {
        'objectKey': objectKey,
        if (hospitalHint != null && hospitalHint.isNotEmpty)
          'hospitalHint': hospitalHint,
        if (reportType != null && reportType.isNotEmpty)
          'reportType': reportType,
      },
    );
    _ensureOk(res, 'enqueueParse');
    return ParseJobDto.fromJson(_json(res));
  }

  Future<ParseJobDto> getParseJob(String id) async {
    final res = await _send('GET', config.uri('/api/v1/parse/jobs/$id'));
    _ensureOk(res, 'getParseJob');
    return ParseJobDto.fromJson(_json(res));
  }

  Future<List<dynamic>> listProtocols() async {
    final res = await _send('GET', config.uri('/api/v1/injections/protocols'));
    _ensureOk(res, 'listProtocols');
    return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
  }

  Future<Map<String, dynamic>> generateSchedule({
    required String drugKey,
    required String startDate,
    String? untilDate,
  }) async {
    final res = await _send(
      'POST',
      config.uri('/api/v1/injections/schedule'),
      body: {
        'drugKey': drugKey,
        'startDate': startDate,
        if (untilDate != null) 'untilDate': untilDate,
      },
    );
    _ensureOk(res, 'generateSchedule');
    return _json(res);
  }

  Future<List<dynamic>> listInjections() async {
    final res = await _send('GET', config.uri('/api/v1/injections'));
    _ensureOk(res, 'listInjections');
    return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
  }

  Future<List<dynamic>> listDueReminders() async {
    final res = await _send('GET', config.uri('/api/v1/reminders/due'));
    _ensureOk(res, 'listDueReminders');
    return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
  }

  Future<Map<String, dynamic>> completeInjection(
    String id, {
    String? actualDate,
    bool rescheduleDelay = true,
  }) async {
    final res = await _send(
      'POST',
      config.uri('/api/v1/injections/$id/complete'),
      body: {
        if (actualDate != null) 'actualDate': actualDate,
        'rescheduleDelay': rescheduleDelay,
      },
    );
    _ensureOk(res, 'completeInjection');
    return _json(res);
  }

  Future<void> ensureInjectionReminderRule({int leadDays = 3}) async {
    try {
      await _send(
        'POST',
        config.uri('/api/v1/reminders'),
        body: {'kind': 'injection', 'leadDays': leadDays, 'enabled': true},
      );
    } catch (_) {
      // 可能已存在；MVP 忽略
    }
  }

  Future<List<dynamic>> listCurrentMedications() async {
    final res = await _send('GET', config.uri('/api/v1/medications/current'));
    _ensureOk(res, 'listCurrentMedications');
    return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
  }

  Future<Map<String, dynamic>> medicationTimeline() async {
    final res = await _send('GET', config.uri('/api/v1/medications/timeline'));
    _ensureOk(res, 'medicationTimeline');
    return _json(res);
  }

  Future<Map<String, dynamic>> createMedication(
      Map<String, dynamic> body) async {
    final res = await _send('POST', config.uri('/api/v1/medications'), body: body);
    _ensureOk(res, 'createMedication');
    return _json(res);
  }

  Future<Map<String, dynamic>> updateMedication(
      String id, Map<String, dynamic> body) async {
    final res = await _send('PATCH', config.uri('/api/v1/medications/$id'),
        body: body);
    _ensureOk(res, 'updateMedication');
    return _json(res);
  }

  Future<Map<String, dynamic>> stopMedication(
    String id, {
    String? reason,
    String? endDate,
  }) async {
    final res = await _send(
      'POST',
      config.uri('/api/v1/medications/$id/stop'),
      body: {
        if (reason != null) 'reason': reason,
        if (endDate != null) 'endDate': endDate,
      },
    );
    _ensureOk(res, 'stopMedication');
    return _json(res);
  }

  Future<Map<String, dynamic>> switchMedication(Map<String, dynamic> body) async {
    final res = await _send(
      'POST',
      config.uri('/api/v1/medications/switch'),
      body: body,
    );
    _ensureOk(res, 'switchMedication');
    return _json(res);
  }

  Future<Map<String, dynamic>> addAdverseEvent(
    String medId,
    Map<String, dynamic> body,
  ) async {
    final res = await _send(
      'POST',
      config.uri('/api/v1/medications/$medId/adverse-events'),
      body: body,
    );
    _ensureOk(res, 'addAdverseEvent');
    return _json(res);
  }

  void dispose() => _client.close();
}
