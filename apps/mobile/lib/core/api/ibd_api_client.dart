import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

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

/// 对接 services/api：files/presign · files/upload · parse/jobs
class IbdApiClient {
  IbdApiClient(this.config, {http.Client? client})
      : _client = client ?? http.Client();

  final ApiConfig config;
  final http.Client _client;

  Future<PresignResult> presign({
    required String filename,
    String contentType = 'application/octet-stream',
    int expiresInSec = 900,
  }) async {
    final res = await _client.post(
      config.uri('/api/v1/files/presign'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'filename': filename,
        'contentType': contentType,
        'expiresInSec': expiresInSec,
      }),
    );
    _ensureOk(res, 'presign');
    return PresignResult.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// 对预签名 URL 直传（local 指向 API；s3 指向 MinIO/OSS）。
  Future<void> uploadBytes({
    required PresignResult presign,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final headers = <String, String>{
      ...presign.headers,
      if (contentType != null) 'content-type': contentType,
    };
    final uri = Uri.parse(presign.uploadUrl);
    final res = await _client.send(
      http.Request(presign.method, uri)
        ..headers.addAll(headers)
        ..bodyBytes = bytes,
    );
    final body = await res.stream.bytesToString();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw IbdApiException(
        'upload failed: HTTP ${res.statusCode}',
        body: body,
      );
    }
  }

  Future<ParseJobDto> enqueueParse({
    required String objectKey,
    String? hospitalHint,
    String? reportType,
    String? patientId,
  }) async {
    final res = await _client.post(
      config.uri('/api/v1/parse/jobs'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'objectKey': objectKey,
        if (hospitalHint != null) 'hospitalHint': hospitalHint,
        if (reportType != null) 'reportType': reportType,
        if (patientId != null) 'patientId': patientId,
      }),
    );
    _ensureOk(res, 'enqueueParse');
    return ParseJobDto.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<ParseJobDto> getParseJob(String id) async {
    final res = await _client.get(config.uri('/api/v1/parse/jobs/$id'));
    _ensureOk(res, 'getParseJob');
    return ParseJobDto.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  void _ensureOk(http.Response res, String op) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw IbdApiException(
        '$op failed: HTTP ${res.statusCode}',
        body: utf8.decode(res.bodyBytes, allowMalformed: true),
      );
    }
  }

  void dispose() => _client.close();
}

class IbdApiException implements Exception {
  IbdApiException(this.message, {this.body});

  final String message;
  final String? body;

  @override
  String toString() =>
      body == null || body!.isEmpty ? message : '$message\n$body';
}
