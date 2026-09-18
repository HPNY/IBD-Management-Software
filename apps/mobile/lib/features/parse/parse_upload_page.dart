import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_config.dart';
import '../../core/api/ibd_api_client.dart';
import '../../core/api/sync_api.dart';
import '../../core/auth/auth_session.dart';
import '../../core/db/repositories.dart';
import '../../core/identity/local_identity.dart';
import '../../core/storage/direct_upload_service.dart';

/// 解析上传：默认不上传；用户明确同意后才调用云端（短时 parse_session）。
class ParseUploadPage extends StatefulWidget {
  const ParseUploadPage({super.key});

  @override
  State<ParseUploadPage> createState() => _ParseUploadPageState();
}

class _ParseUploadPageState extends State<ParseUploadPage> {
  IbdApiClient? _api;
  final _labRepo = LabRepository();
  final _hospitalCtrl = TextEditingController();
  final _reportTypeCtrl = TextEditingController(text: '血常规');
  String? _fileName;
  Uint8List? _bytes;
  String _stage = 'idle';
  List<dynamic> _items = [];
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _hospitalCtrl.dispose();
    _reportTypeCtrl.dispose();
    _api?.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _items = [];
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

  Future<void> _consentAndParse() async {
    final bytes = _bytes;
    final name = _fileName;
    if (bytes == null || name == null) {
      setState(() => _error = '请先选择报告文件');
      return;
    }

    final identity = context.read<LocalIdentity>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认上传到云端解析？'),
        content: Text(
          '文件「$name」（${bytes.length} 字节）将上传到服务器进行 AI/模板解析。\n'
          '应用标识：${identity.uuid}\n'
          '使用 30 分钟短时解析会话，无需长期账号。\n\n'
          '若取消，则不会上传任何数据。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('同意上传并解析'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      setState(() => _stage = 'cancelled');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _stage = 'parse_session';
    });

    try {
      final config = ApiConfig.dev();
      final sessionJson =
          await SyncApi(config).parseSession(identity.uuid);
      final token = sessionJson['accessToken'] as String;
      // 注入短时 token 到会话
      final session = AuthSession.parseSession(token, identity.uuid);
      _api = IbdApiClient(config, session);

      final upload = DirectUploadService(_api!);
      final job = await upload.uploadAndEnqueue(
        filename: name,
        bytes: bytes,
        hospitalHint: _hospitalCtrl.text.trim().isEmpty
            ? null
            : _hospitalCtrl.text.trim(),
        reportType: _reportTypeCtrl.text.trim().isEmpty
            ? null
            : _reportTypeCtrl.text.trim(),
        onProgress: (p) {
          if (mounted) setState(() => _stage = p.stage);
        },
      );
      final done = await upload.waitUntilDone(job.id);
      if (!mounted) return;
      setState(() {
        _stage = done.status;
        _items = done.items;
      });

      if (done.items.isNotEmpty) {
        await _labRepo.insert(
          date: DateTime.now().toIso8601String().substring(0, 10),
          hospital: _hospitalCtrl.text.trim().isEmpty
              ? null
              : _hospitalCtrl.text.trim(),
          source: 'ai',
          items: done.items
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('上传检验报告')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.privacy_tip),
              title: Text('默认不上传'),
              subtitle: Text('仅在你点击「同意上传并解析」后，本次文件才会离开本机。'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hospitalCtrl,
            decoration: const InputDecoration(
              labelText: '医院名称（可选）',
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
            label: Text(_fileName ?? '选择文件（仍不会上传）'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _consentAndParse,
            child: Text(_busy ? '处理中…' : '选择文件并确认上传解析'),
          ),
          const SizedBox(height: 12),
          if (_stage != 'idle') Text('阶段：$_stage'),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('解析结果（已写入本机）',
                style: Theme.of(context).textTheme.titleMedium),
            ..._items.map((item) {
              final m = Map<String, dynamic>.from(item as Map);
              return ListTile(
                dense: true,
                title: Text('${m['name'] ?? ''}'),
                subtitle: Text('${m['value'] ?? ''} ${m['unit'] ?? ''}'),
              );
            }),
          ],
        ],
      ),
    );
  }
}
