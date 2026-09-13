import 'dart:typed_data';

import '../../api/ibd_api_client.dart';

class UploadProgress {
  UploadProgress(this.stage, {this.job});

  final String stage;
  final ParseJobDto? job;
}

class DirectUploadService {
  DirectUploadService(this._api);

  final IbdApiClient _api;

  Future<ParseJobDto> uploadAndEnqueue({
    required String filename,
    required Uint8List bytes,
    String? contentType,
    String? hospitalHint,
    String? reportType,
    void Function(UploadProgress progress)? onProgress,
  }) async {
    onProgress?.call(UploadProgress('presign'));
    final presign = await _api.presign(
      filename: filename,
      contentType: contentType ?? _guessContentType(filename),
    );

    onProgress?.call(UploadProgress('upload'));
    await _api.uploadBytes(
      presign: presign,
      bytes: bytes,
      contentType: contentType ?? _guessContentType(filename),
    );

    onProgress?.call(UploadProgress('enqueue'));
    final job = await _api.enqueueParse(
      objectKey: presign.objectKey,
      hospitalHint: hospitalHint,
      reportType: reportType,
    );
    onProgress?.call(UploadProgress('queued', job: job));
    return job;
  }

  Future<ParseJobDto> waitUntilDone(
    String jobId, {
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 2),
    void Function(ParseJobDto job)? onUpdate,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final job = await _api.getParseJob(jobId);
      onUpdate?.call(job);
      if (job.status == 'done' || job.status == 'failed') return job;
      await Future<void>.delayed(pollInterval);
    }
    throw TimeoutException('parse job $jobId timed out');
  }

  static String _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }
}

class TimeoutException implements Exception {
  TimeoutException(this.message);
  final String message;
  @override
  String toString() => message;
}
