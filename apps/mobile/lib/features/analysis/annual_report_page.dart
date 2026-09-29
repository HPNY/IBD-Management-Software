import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/report/annual_report.dart';

/// 年度报告：默认最近完整年自动构建 + 同比/检查手术汇总 + 分享（G3）。
class AnnualReportPage extends StatefulWidget {
  const AnnualReportPage({super.key});

  @override
  State<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends State<AnnualReportPage> {
  late int _year = AnnualReportBuilder.defaultRecentCompleteYear();
  AnnualReport? _report;
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    // G3 自动体验：进入即构建默认年份，无需手点。
    _build();
  }

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

  void _shiftYear(int delta) {
    setState(() {
      _year += delta;
      _report = null;
    });
    _build();
  }

  @override
  Widget build(BuildContext context) {
    final text = _report?.toText() ?? '';
    final delta = _report?.delta;
    return Scaffold(
      appBar: AppBar(title: Text('$_year 年度报告')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _year > 2015 && !_busy
                    ? () => _shiftYear(-1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('$_year', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                onPressed: _year < DateTime.now().year && !_busy
                    ? () => _shiftYear(1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _build,
                child: Text(_busy ? '生成中…' : '重新生成'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '默认展示 ${AnnualReportBuilder.defaultRecentCompleteYear()} 年（最近完整年），可用箭头切换。',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_msg!, style: const TextStyle(color: Colors.orange)),
            ),
          if (_busy && _report == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (_report != null) ...[
            if (delta != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '与 ${_year - 1} 年对比',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(delta.summary),
                    ],
                  ),
                ),
              ),
            if ((_report!.exams.isNotEmpty || _report!.surgeries.isNotEmpty) &&
                delta != null)
              const SizedBox(height: 4),
            if (_report!.exams.isNotEmpty || _report!.surgeries.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '检查 ${_report!.exams.length} · 手术 ${_report!.surgeries.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          for (final e in _report!.exams.take(3))
                            '· ${e['date']} ${e['type'] ?? ''}',
                          for (final s in _report!.surgeries.take(3))
                            '· ${s['date']} ${s['type'] ?? s['procedure'] ?? ''}',
                        ].join('\n'),
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
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
              '正在自动汇总本机一年数据…',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
