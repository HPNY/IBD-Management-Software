import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
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

  Future<void> _save() async {
    final n = DateTime.now();
    final date =
        '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    final band = SurveyKit.interpret(_kind, _total);
    await _repo.save(
      date: date,
      kind: _kind,
      total: _total,
      detail: {
        'band': band,
        'scores': _scores,
        'labels': [
          for (var i = 0; i < _scores.length; i++)
            SurveyKit.optionLabel(_kind, _scores[i]),
        ],
      },
    );
    await _loadHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存：${SurveyKit.kindTitle(_kind)} $_total 分 · $band')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = SurveyKit.questionsFor(_kind);
    final options = SurveyKit.optionsFor(_kind);
    final band = SurveyKit.interpret(_kind, _total);
    final intro = SurveyKit.introFor(_kind);

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
                  '当前合计 $_total 分 · $band',
                  style: const TextStyle(
                    color: IbdColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
          const Text('历史',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ..._history.map((h) {
            final raw = '${h['detail_json'] ?? ''}';
            final m = RegExp(r'"band"\\s*:\\s*"([^"]+)"').firstMatch(raw) ??
                RegExp(r'"band":\s*"([^"]+)"').firstMatch(raw);
            final bandH = m?.group(1) ?? '';
            final title = SurveyKit.kindTitle('${h['kind']}');
            return Card(
              child: ListTile(
                dense: true,
                title: Text('$title · ${h['total']} 分'),
                subtitle: Text('${h['date']}${bandH.isEmpty ? '' : ' · $bandH'}'),
              ),
            );
          }),
        ],
      ),
    );
  }
}
