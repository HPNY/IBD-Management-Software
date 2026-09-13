import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_config.dart';
import '../../core/api/ibd_api_client.dart';
import '../../core/storage/direct_upload_service.dart';

/// 检验 PDF 直传 + 解析入口（MVP）。
class ParseUploadPage extends StatefulWidget {
  const ParseUploadPage({super.key, IbdApiClient? api}) : _api = api;

  final IbdApiClient? _api;

  @override
  State<ParseUploadPage> createState() => _ParseUploadPageState();
}

class _ParseUploadPageState extends State<ParseUploadPage> {
  late final IbdApiClient _api = widget._api ?? IbdApiClient(ApiConfig.dev());
  late final DirectUploadService _upload = DirectUploadService(_api);

  final _hospitalCtrl = TextEditingController();
  final _reportTypeCtrl = TextEditingController(text: '血常规');

  String? _fileName;
  Uint8List? _bytes;
  String _stage = 'idle';
  ParseJobDto? _job;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _hospitalCtrl.dispose();
    _reportTypeCtrl.dispose();
    if (widget._api == null) _api.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _job = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return;
    setState(() {
      _fileName = file.name;
      _bytes = file.bytes;
    });
  }

  Future<void> _startUpload() async {
    final bytes = _bytes;
    final name = _fileName;
    if (bytes == null || name == null) {
      setState(() => _error = '请先选择报告文件');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _stage = 'starting';
    });
    try {
      final job = await _upload.uploadAndEnqueue(
        filename: name,
        bytes: bytes,
        hospitalHint:
            _hospitalCtrl.text.trim().isEmpty ? null : _hospitalCtrl.text.trim(),
        reportType: _reportTypeCtrl.text.trim().isEmpty
            ? null
            : _reportTypeCtrl.text.trim(),
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _stage = p.stage;
              _job = p.job ?? _job;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() => _job = job);

      final done = await _upload.waitUntilDone(
        job.id,
        onUpdate: (j) {
          if (mounted) setState(() => _job = j);
        },
      );
      if (!mounted) return;
      setState(() {
        _job = done;
        _stage = done.status;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _stage = 'error';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    return Scaffold(
      appBar: AppBar(title: const Text('上传检验报告')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _hospitalCtrl,
            decoration: const InputDecoration(
              labelText: '医院名称（可选，命中 Skill）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reportTypeCtrl,
            decoration: const InputDecoration(
              labelText: '报告类型',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.attach_file),
            label: Text(_fileName ?? '选择 PDF / 图片 / 文本'),
          ),
          if (_bytes != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_bytes!.length} bytes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _startUpload,
            child: Text(_busy ? '处理中…' : '直传并解析'),
          ),
          const SizedBox(height: 16),
          if (_stage != 'idle')
            Card(
              child: ListTile(
                title: Text('阶段：$_stage'),
                subtitle: job == null
                    ? null
                    : Text(
                        'job=${job.id}\nstatus=${job.status}\n'
                        'items=${job.items.length}'
                        '${job.error == null ? '' : '\nerror=${job.error}'}',
                      ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (job != null && job.items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('解析结果', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...job.items.map((item) {
              final map = Map<String, dynamic>.from(item as Map);
              return ListTile(
                dense: true,
                title: Text('${map['name'] ?? map['nameNorm'] ?? ''}'),
                subtitle: Text(
                  '${map['value'] ?? ''} ${map['unit'] ?? ''}'
                  '${map['flag'] == null ? '' : ' ${map['flag']}'}',
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
