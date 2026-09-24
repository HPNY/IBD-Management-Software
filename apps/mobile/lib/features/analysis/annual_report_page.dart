import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/report/annual_report.dart';

/// 年度报告：生成 + 复制/分享（PRD V1.5）。
class AnnualReportPage extends StatefulWidget {
  const AnnualReportPage({super.key});

  @override
  State<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends State<AnnualReportPage> {
  late int _year = DateTime.now().year;
  AnnualReport? _report;
  bool _busy = false;
  String? _msg;

  Future<void> _build() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final r = await AnnualReportBuilder().build(year: _year);
      setState(() => _report = r);
    } catch (e) {
      setState(() => _msg = '生成失败：$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _report?.toText() ?? '';
    return Scaffold(
      appBar: AppBar(title: Text('$_year 年度报告')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _year > 2015 ? () => setState(() => _year--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('$_year', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                onPressed: _year < DateTime.now().year
                    ? () => setState(() => _year++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _build,
                child: Text(_busy ? '生成中…' : '生成报告'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_msg!, style: const TextStyle(color: Colors.orange)),
            ),
          if (_report != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(text, style: const TextStyle(height: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Share.share(text),
              icon: const Icon(Icons.share_rounded),
              label: const Text('分享年度报告'),
            ),
          ] else if (!_busy)
            const Text(
              '点「生成报告」汇总本机一年数据。\n'
              '含检验次数、用药变更、症状打卡、注射与平均腹痛。',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
