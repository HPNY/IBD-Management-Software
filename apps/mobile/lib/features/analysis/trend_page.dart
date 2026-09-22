import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/ui/theme.dart';

/// D1：核心检验指标趋势（本机 labs 数据，Canvas 折线）
class TrendPage extends StatefulWidget {
  const TrendPage({super.key, this.embedded = true});

  final bool embedded;

  @override
  State<TrendPage> createState() => _TrendPageState();
}

class _TrendPageState extends State<TrendPage> {
  final _repo = LabSeriesRepository();
  String _metric = '超敏C反应蛋白';
  List<Map<String, dynamic>> _series = [];
  Map<String, Map<String, dynamic>> _latest = {};
  bool _busy = false;

  static const metrics = [
    '超敏C反应蛋白',
    '血沉',
    '粪便钙卫蛋白',
    '淋巴细胞',
    '白蛋白',
    '血红蛋白',
    '尿酸',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final s = await _repo.seriesByName(_metric);
      final latest = await _repo.latestCore();
      if (!mounted) return;
      setState(() {
        _series = s;
        _latest = latest;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = _series
        .map((e) => (e['value'] as num?)?.toDouble() ?? 0)
        .toList();
    final maxV = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final minV = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);

    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('指标趋势'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: metrics.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final m = metrics[i];
                      final sel = m == _metric;
                      return ChoiceChip(
                        label: Text(m, style: const TextStyle(fontSize: 12)),
                        selected: sel,
                        onSelected: (_) {
                          setState(() => _metric = m);
                          _load();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 240,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: IbdColors.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _series.isEmpty
                      ? Center(
                          child: Text(
                            '暂无「$_metric」数据\n可到首页手动录入检验',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: IbdColors.textSecondary),
                          ),
                        )
                      : CustomPaint(
                          painter: _LineChartPainter(
                            values: values,
                            minV: minV,
                            maxV: maxV,
                            dates: _series.map((e) => '${e['date']}').toList(),
                          ),
                          size: const Size(double.infinity, 240),
                        ),
                ),
                const SizedBox(height: 8),
                if (_series.isNotEmpty)
                  Text(
                    '$_metric：min ${minV.toStringAsFixed(2)} · max ${maxV.toStringAsFixed(2)} · '
                    '${_series.length} 个点',
                    style: const TextStyle(
                      fontSize: 12,
                      color: IbdColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  '最近一次核心指标',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (_latest.isEmpty)
                  const Text('暂无数据',
                      style: TextStyle(color: IbdColors.textSecondary)),
                ..._latest.entries.map((e) {
                  final v = e.value['value'];
                  return Card(
                    child: ListTile(
                      dense: true,
                      title: Text(e.key),
                      trailing: Text(
                        '$v ${e.value['unit'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${e.value['date']}'),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.minV,
    required this.maxV,
    required this.dates,
  });

  final List<double> values;
  final double minV;
  final double maxV;
  final List<String> dates;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paintLine = Paint()
      ..color = IbdColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final paintDot = Paint()..color = IbdColors.primaryDark;
    final paintGrid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    const pad = 24.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    for (var i = 0; i <= 4; i++) {
      final y = pad + h * i / 4;
      canvas.drawLine(Offset(pad, y), Offset(size.width - pad, y), paintGrid);
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? pad + w / 2
          : pad + w * i / (values.length - 1);
      final y = pad + h - (values[i] - minV) / range * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, paintDot);
    }
    canvas.drawPath(path, paintLine);

    final tp = TextPainter(
      text: TextSpan(
        text: maxV.toStringAsFixed(1),
        style: const TextStyle(fontSize: 10, color: IbdColors.textSecondary),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(0, 10));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values ||
      old.minV != minV ||
      old.maxV != maxV;
}
