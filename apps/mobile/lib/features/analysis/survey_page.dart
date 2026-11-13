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
  /// null = 未作答；未答完不允许保存（B-O-08，避免未答被记 0 分）。
  /// U13 的「尚未作答」文案直接复用这套 null 语义，不再额外维护 Set。
  List<int?> _scores = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _resetKind(_kind);
    _loadHistory();
  }

  void _resetKind(String kind) {
    final qs = SurveyKit.questionsFor(kind);
    setState(() {
      _kind = kind;
      _scores = List<int?>.filled(qs.length, null);
    });
  }

  Future<void> _loadHistory() async {
    final h = await _repo.listAll();
    if (mounted) setState(() => _history = h);
  }

  int get _answered => _scores.where((v) => v != null).length;
  bool get _complete => _scores.isNotEmpty && _answered == _scores.length;

  int get _total => _scores.fold(0, (a, b) => a + (b ?? 0));

  Sf36DomainResult? get _sf36Domains => _kind == 'SF36' &&
          _scores.length == 36 &&
          _complete
      ? Sf36Scoring.scoreAll(_scores.cast<int>())
      : null;

  List<Sf36TrendPoint> get _sf36Trend => sf36TrendFromHistory(_history);

  Future<void> _save() async {
    if (!_complete) {
      final left = _scores.length - _answered;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('还有 $left 题未作答，量表需全部完成后才能保存')),
      );
      return;
    }
    // PHQ-9 第 9 题（自伤念头）≥1 分：先给固定求助卡，不做诊断。
    if (_kind == 'PHQ9' && (_scores[8] ?? 0) >= 1) {
      final cont = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要一些支持吗？'),
          content: const Text(
            '你提到过「不如死掉或伤害自己」的念头。这不是你的错，也不代表必须独自扛。\n\n'
            '可以现在联系信任的家人/朋友，或拨打当地心理援助热线；'
            '若有立即伤害自己的风险，请直接前往急诊。\n\n'
            '本应用只做记录，不能替代专业帮助。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('我知道了，继续保存'),
            ),
          ],
        ),
      );
      if (cont != true) return;
    }
    final n = DateTime.now();
    final date =
        '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    final band = SurveyKit.interpret(_kind, _total);
    final domains = _sf36Domains;
    final detail = <String, dynamic>{
      'band': band,
      'scores': _scores.cast<int>(),
      'labels': [
        for (var i = 0; i < _scores.length; i++)
          SurveyKit.optionLabel(_kind, _scores[i] ?? 0),
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
    final intro = SurveyKit.introFor(_kind);
    final band = SurveyKit.interpret(_kind, _total);
    final domainResult = _sf36Domains;

    return Scaffold(
      backgroundColor: context.ibd.bg,
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
              color: context.ibd.brandSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SurveyKit.kindTitle(_kind),
                  style: TextStyle(
                    color: context.ibd.brandInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  intro,
                  style: TextStyle(
                    color: context.ibd.brandInk,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _answered == 0
                      ? '尚未作答'
                      : domainResult == null
                          ? '已答 $_answered/${_scores.length} · 当前合计 $_total 分 · $band'
                          : '已答 $_answered/${_scores.length} · 简化合计 $_total 分 · $band',
                  style: TextStyle(
                    color: context.ibd.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (domainResult != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '标准 8 维均分 ${domainResult.stdAverage} · 分越高越好',
                    style: TextStyle(
                      color: context.ibd.brandInk,
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
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.ibd.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(questions.length, (i) {
            final q = questions[i];
            final score = _scores[i];
            final label =
                score == null ? '未作答' : SurveyKit.optionLabel(_kind, score);
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
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.ibd.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      score == null ? '尚未选择' : '选：$score · $label',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.ibd.brandInk,
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
                            setState(() {
                              _scores[i] = o.value;
                            });
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
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('保存量表'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '仅供自我记录与就医沟通参考，不能替代医生诊断。',
            style: TextStyle(fontSize: 12, color: context.ibd.textSecondary),
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
        color: context.ibd.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '8 维均分：${stds.map((e) => e.round()).join(' → ')}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: context.ibd.brandInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${recent.first.date} → ${recent.last.date} · ${recent.length} 次',
            style: TextStyle(
              fontSize: 11.5,
              color: context.ibd.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _DomainSparkPainter(
                points: recent,
                gridColor: context.ibd.divider,
              ),
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
                  style: TextStyle(
                    fontSize: 11,
                    color: context.ibd.textSecondary,
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
  _DomainSparkPainter({required this.points, required this.gridColor});

  final List<Sf36TrendPoint> points;

  /// CustomPainter 无 BuildContext，网格色由 build 处注入（U5）。
  final Color gridColor;

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
      ..color = gridColor
      ..strokeWidth = 1;
    for (final t in [0.0, 50.0, 100.0]) {
      final y = pad + h - (t / 100.0) * h;
      canvas.drawLine(Offset(pad, y), Offset(size.width - pad, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _DomainSparkPainter old) => old.points != points;
}
