import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/survey/survey_kit.dart';
import '../../core/ui/theme.dart';

/// 量表：PHQ-9 / 简版 IBDQ / MiniQoL（本地记录，非诊断）
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
    setState(() {
      _kind = kind;
      _scores = List.filled(qs.length, 0);
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
      detail: {'band': band, 'scores': _scores},
    );
    await _loadHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存：$_kind $_total 分 · $band')),
      );
    }
  }

  int get _maxScore => _kind == 'PHQ9' ? 3 : 4;

  @override
  Widget build(BuildContext context) {
    final questions = SurveyKit.questionsFor(_kind);
    final band = SurveyKit.interpret(_kind, _total);
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(title: const Text('生活质量量表')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'PHQ9', label: Text('PHQ-9')),
              ButtonSegment(value: 'IBDQ', label: Text('简版 IBDQ')),
              ButtonSegment(value: 'MiniQoL', label: Text('Mini QoL')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => _resetKind(s.first),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IbdColors.chipBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '当前：$_total 分 · $band\n本量表仅作自我记录，不能替代医生评估。',
              style: const TextStyle(
                color: IbdColors.primaryDark,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(questions.length, (i) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ${questions[i]}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Slider(
                      value: _scores[i].toDouble(),
                      min: 0,
                      max: _maxScore.toDouble(),
                      divisions: _maxScore,
                      label: '${_scores[i]}',
                      onChanged: (v) => setState(() => _scores[i] = v.round()),
                    ),
                    Text('得分 ${_scores[i]}',
                        style: const TextStyle(
                            fontSize: 12, color: IbdColors.textSecondary)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('保存量表')),
          const SizedBox(height: 20),
          const Text('历史',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ..._history.map((h) {
            final raw = '${h['detail_json'] ?? ''}';
            final m = RegExp(r'"band"\s*:\s*"([^"]+)"').firstMatch(raw);
            final bandH = m?.group(1) ?? '';
            return Card(
              child: ListTile(
                dense: true,
                title: Text('${h['kind']} · ${h['total']} 分'),
                subtitle: Text('${h['date']}${bandH.isEmpty ? '' : ' · $bandH'}'),
              ),
            );
          }),
        ],
      ),
    );
  }
}
