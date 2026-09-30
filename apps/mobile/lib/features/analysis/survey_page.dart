import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/survey/sf36_scoring.dart';
import '../../core/survey/sf36_trend.dart';
import '../../core/survey/survey_kit.dart';
import '../../core/ui/theme.dart';

/// 量表：通俗选项 + 示例说明（本地记录，非诊断）
class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final _repo = QualitySurveyRepository();
  String _kind = 'PHQ9';
  List<int> _scores = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _resetKind(_kind);
    _loadHistory();
  }

  void _resetKind(String kind) {
    final qs = SurveyKit.questionsFor(kind);
    final opts = SurveyKit.optionsFor(kind);
    final def = opts.first.value;
    setState(() {
      _kind = kind;
      _scores = List.filled(qs.length, def);
    });
  }

  Future<void> _loadHistory() async {
    final h = await _repo.listAll();
    if (mounted) setState(() => _history = h);
  }

  int get _total => _scores.fold(0, (a, b) => a + b);

  Sf36DomainResult? get _sf36Domains =>
      _kind == 'SF36' && _scores.length == 36 ? Sf36Scoring.scoreAll(_scores) : null;

  List<Sf36TrendPoint> get _sf36Trend => sf36TrendFromHistory(_history);

  Future<void> _save() async {
    final n = DateTime.now();
    final date =
        '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    final band = SurveyKit.interpret(_kind, _total);
    final domains = _sf36Domains;
    final detail = <String, dynamic>{
      'band': band,
      'scores': _scores,
      'labels': [
        for (var i = 0; i < _scores.length; i++)
          SurveyKit.optionLabel(_kind, _scores[i]),
      ],
    };
    if (domains != null) {
      detail['scoring'] = 'v1-parallel';
      detail['domains'] = domains.domains;
      detail['stdAverage'] = domains.stdAverage;
    }
    await _repo.save(
      date: date,
      kind: _kind,
      total: _total,
      detail: detail,
    );
    await _loadHistory();
    if (mounted) {
      final msg = domains == null
          ? '已保存：${SurveyKit.kindTitle(_kind)} $_total 分 · $band'
          : '已保存：SF-36 · 简化 $_total 分 · 8 维均分 ${domains.stdAverage}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = SurveyKit.questionsFor(_kind);
    final options = SurveyKit.optionsFor(_kind);
    final band = SurveyKit.interpret(_kind, _total);
    final intro = SurveyKit.introFor(_kind);
    final domainResult = _sf36Domains;

    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(title: const Text('生活质量量表')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'PHQ9', label: Text('情绪 PHQ-9')),
              ButtonSegment(value: 'IBDQ', label: Text('肠病 IBDQ')),
              ButtonSegment(value: 'SF36', label: Text('通用 SF-36')),
              ButtonSegment(value: 'MiniQoL', label: Text('快速评分')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => _resetKind(s.first),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IbdColors.chipBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SurveyKit.kindTitle(_kind),
                  style: const TextStyle(
                    color: IbdColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  intro,
                  style: const TextStyle(
                    color: IbdColors.primaryDark,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  domainResult == null
                      ? '当前合计 $_total 分 · $band'
                      : '简化合计 $_total 分 · $band',
                  style: const TextStyle(
                    color: IbdColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (domainResult != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '标准 8 维均分 ${domainResult.stdAverage} · 分越高越好',
                    style: const TextStyle(
                      color: IbdColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in domainResult.domains.entries)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${sf36DomainLabels[e.key] ?? e.key} ${e.value}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '选项说明（各题相同）',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 6),
          ...options.map(
            (o) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${o.value} · ${o.label} — ${o.detail}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: IbdColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(questions.length, (i) {
            final q = questions[i];
            final score = _scores[i];
            final label = SurveyKit.optionLabel(_kind, score);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ${q.text}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '怎么理解：${q.hint}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: IbdColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '选：$score · $label',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: IbdColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: options.map((o) {
                        final sel = o.value == score;
                        return ChoiceChip(
                          label: Text(
                            '${o.value} ${o.label}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          selected: sel,
                          onSelected: (_) {
                            setState(() => _scores[i] = o.value);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('保存量表')),
          const SizedBox(height: 8),
          const Text(
            '仅供自我记录与就医沟通参考，不能替代医生诊断。',
            style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_sf36Trend.isNotEmpty) ...[
            const Text('SF-36 · 8 维趋势（近 8 次）',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            _Sf36TrendCard(points: _sf36Trend),
            const SizedBox(height: 20),
          ],
          const Text('历史',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ..._history.map((h) {
            final raw = '${h['detail_json'] ?? ''}';
            final m = RegExp(r'"band"\\s*:\\s*"([^"]+)"').firstMatch(raw) ??
                RegExp(r'"band":\s*"([^"]+)"').firstMatch(raw);
            final bandH = m?.group(1) ?? '';
            final title = SurveyKit.kindTitle('${h['kind']}');
            final stdAvgM = RegExp(r'"stdAverage"\s*:\s*(\d+)').firstMatch(raw);
            final domainsM = RegExp(r'"domains"\s*:\s*\{([^}]+)\}').firstMatch(raw);
            var subtitle = '${h['date']}${bandH.isEmpty ? '' : ' · $bandH'}';
            var titleSuffix = ' · ${h['total']} 分';
            if (stdAvgM != null && domainsM != null) {
              titleSuffix = ' · 简化 ${h['total']} · 均分 ${stdAvgM.group(1)}';
              final pairs = <MapEntry<String, int>>[];
              for (final pm
                  in RegExp(r'"(\w+)"\s*:\s*(\d+)').allMatches(domainsM.group(1)!)) {
                final id = pm.group(1)!;
                if (!sf36DomainLabels.containsKey(id)) continue;
                pairs.add(MapEntry(id, int.parse(pm.group(2)!)));
              }
              pairs.sort((a, b) => a.value.compareTo(b.value));
              final weak = pairs.take(2).map(
                    (e) => '${sf36DomainLabels[e.key]} ${e.value}',
                  );
              if (weak.isNotEmpty) subtitle = '$subtitle · 较低：${weak.join(' · ')}';
            }
            return Card(
              child: ListTile(
                dense: true,
                title: Text('$title$titleSuffix'),
                subtitle: Text(subtitle),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// SF-36 域分趋势卡：最近 8 次有 domains 的记录。
class _Sf36TrendCard extends StatelessWidget {
  const _Sf36TrendCard({required this.points});

  final List<Sf36TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final recent =
        points.length <= 8 ? points : points.sublist(points.length - 8);
    final stds = [for (final p in recent) p.stdAverage.toDouble()];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IbdColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '8 维均分：${stds.map((e) => e.round()).join(' → ')}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: IbdColors.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${recent.first.date} → ${recent.last.date} · ${recent.length} 次',
            style: const TextStyle(
              fontSize: 11.5,
              color: IbdColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _DomainSparkPainter(points: recent),
              size: const Size(double.infinity, 120),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in sf36DomainLabels.keys)
                Text(
                  sf36DomainLabels[id]!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: IbdColors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DomainSparkPainter extends CustomPainter {
  _DomainSparkPainter({required this.points});

  final List<Sf36TrendPoint> points;

  static const _colors = [
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFFDB2777),
    Color(0xFF4B5563),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const pad = 8.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final ids = sf36DomainLabels.keys.toList();
    for (var di = 0; di < ids.length; di++) {
      final vals = domainSeries(points, ids[di]);
      if (vals.length < 2) continue;
      final paint = Paint()
        ..color = _colors[di % _colors.length].withValues(alpha: 0.85)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < vals.length; i++) {
        final x = pad + w * i / (vals.length - 1);
        final y = pad + h - (vals[i] / 100.0) * h;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
    final grid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (final t in [0.0, 50.0, 100.0]) {
      final y = pad + h - (t / 100.0) * h;
      canvas.drawLine(Offset(pad, y), Offset(size.width - pad, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _DomainSparkPainter old) => old.points != points;
}
