import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/export/data_exporter.dart';
import '../../core/notify/local_notify.dart';
import '../../core/ui/theme.dart';

/// 数据导出：多表 CSV + JSON，仅本机生成后系统分享。
class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  final _exporter = DataExporter();
  bool _busy = false;
  String? _message;
  Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final labs = await LabRepository().listAll();
    final meds = await MedicationRepository().listAll();
    final sym = await SymptomRepository().listAll();
    final qol = await QualitySurveyRepository().listAll();
    if (!mounted) return;
    setState(() {
      _counts = {
        '检验': labs.length,
        '用药': meds.length,
        '症状': sym.length,
        '量表': qol.length,
      };
    });
  }

  Future<void> _exportCsv() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final path = await _exporter.exportAllAndShare();
      if (mounted) setState(() => _message = '已生成 CSV 并调起分享：$path');
    } catch (e) {
      if (mounted) setState(() => _message = '导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(title: const Text('数据导出')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_rounded),

            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _counts.entries
                .map(
                  (e) => Chip(
                    label: Text('${e.key} ${e.value}'),
                    backgroundColor: IbdColors.chipBg,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _exportCsv,
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(_busy ? '导出中…' : '导出 CSV 并分享'),
          ),
          const SizedBox(height: 8),
          const Text(
            '包含：labs.csv · medications.csv · symptoms.csv · surveys.csv',
            style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!),
            ),
          const SizedBox(height: 24),
          const Text(
            '系统通知',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_rounded),
              title: const Text('本地通知能力'),
              subtitle: const Text(
                '注射提醒已接入系统通知（本地优先）。\n'
                '远程推送可选，在「我的 · 系统推送」开启；正文仅通用文案。',
              ),
              trailing: TextButton(
                onPressed: () async {
                  await LocalNotifyService.instance.showTestNotification();
                  if (mounted) {
                    setState(() => _message = '已发送系统通知测试');
                  }
                },
                child: const Text('测试'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
