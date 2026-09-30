import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/drug/drug_review_model.dart';
import '../../core/ui/theme.dart';

/// D2：药物评价（本地列表 + 表单 + 匿名上传/聚合）。
class DrugReviewPage extends StatefulWidget {
  const DrugReviewPage({super.key, this.reviewRepo, this.medRepo});

  final DrugReviewRepository? reviewRepo;
  final MedicationRepository? medRepo;

  @override
  State<DrugReviewPage> createState() => _DrugReviewPageState();
}

class _DrugReviewPageState extends State<DrugReviewPage> {
  late final DrugReviewRepository _repo =
      widget.reviewRepo ?? DrugReviewRepository();
  late final MedicationRepository _meds =
      widget.medRepo ?? MedicationRepository();

  final _drugCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _summary;
  String _ibdType = 'CD';
  int _efficacy = 3;
  int _se = 0;
  final Set<String> _seTypes = {};
  bool _stillUsing = true;
  List<Map<String, dynamic>> _rows = [];
  List<String> _drugNames = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _drugCtrl.dispose();
    _commentCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSummary(String drug) async {
    if (drug.isEmpty) return;
    final all = _rows
        .map(
          (r) => DrugReview(
            drugName: '${r['drug_name']}',
            ibdType: '${r['ibd_type'] ?? 'unknown'}',
            efficacy: (r['efficacy'] as num?)?.toInt() ?? 0,
            seSideEffect: (r['se_side_effect'] as num?)?.toInt() ?? 0,
            comment: r['comment'] as String?,
          ),
        )
        .toList();
    final agg = aggregateLocal(drug, all);
    setState(() {
      _summary = {
        'drugName': agg.drugName,
        'avgEfficacy': agg.avgEfficacy,
        'count': agg.count,
        'seDist': [agg.seDist[0] ?? 0, agg.seDist[1] ?? 0, agg.seDist[2] ?? 0, agg.seDist[3] ?? 0],
      };
    });
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final rows = await _repo.listAll();
      final meds = await _meds.listAll();
      final names = <String>{for (final m in meds) '${m['drug_name']}'};
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _drugNames = names.where((e) => e.isNotEmpty).toList();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final drug = _drugCtrl.text.trim();
    if (drug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写药品名称')),
      );
      return;
    }
    final review = DrugReview(
      drugName: drug,
      ibdType: _ibdType,
      efficacy: _efficacy,
      seSideEffect: _se,
      sideEffectTypes: _seTypes.toList(),
      stillUsing: _stillUsing,
      comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
    );
    // D2.5：上传 payload 仅白名单（本地保存完整，上云走白名单）
    drugReviewUploadPayload(review);
    await _repo.insert(
      drugName: review.drugName,
      efficacy: review.efficacy,
      seSideEffect: review.seSideEffect,
      ibdType: review.ibdType,
      sideEffectTypes: review.sideEffectTypes.join(','),
      stillUsing: review.stillUsing,
      comment: review.comment,
    );
    _drugCtrl.clear();
    _commentCtrl.clear();
    _seTypes.clear();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存我的评价（本机）')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(
        title: const Text('药物评价'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '主观评价仅供病友参考，不替代医生建议。不含检验值/病历。',
                  style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
                ),
                const SizedBox(height: 12),
                const Text('写下我的评价',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                Autocomplete<String>(
                  optionsBuilder: (v) => _drugNames.where(
                    (e) => e.contains(v.text),
                  ),
                  onSelected: (v) => _drugCtrl.text = v,
                  fieldViewBuilder: (context, c, focus, _) {
                    c.text = _drugCtrl.text;
                    return TextField(
                      controller: c,
                      focusNode: focus,
                      decoration: const InputDecoration(
                        labelText: '药品名称',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('IBD 类型 '),
                  ChoiceChip(
                    label: const Text('克罗恩'),
                    selected: _ibdType == 'CD',
                    onSelected: (_) => setState(() => _ibdType = 'CD'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('溃疡性结肠炎'),
                    selected: _ibdType == 'UC',
                    onSelected: (_) => setState(() => _ibdType = 'UC'),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('整体疗效 $_efficacy 星'),
                Slider(
                  value: _efficacy.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$_efficacy',
                  onChanged: (v) => setState(() => _efficacy = v.round()),
                ),
                Text('副作用严重程度 ${['无', '轻', '中', '重'][_se]}'),
                Slider(
                  value: _se.toDouble(),
                  min: 0,
                  max: 3,
                  divisions: 3,
                  label: ['无', '轻', '中', '重'][_se],
                  onChanged: (v) => setState(() => _se = v.round()),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final t in kSideEffectTypes)
                      FilterChip(
                        label: Text(t, style: const TextStyle(fontSize: 12)),
                        selected: _seTypes.contains(t),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _seTypes.add(t);
                          } else {
                            _seTypes.remove(t);
                          }
                        }),
                      ),
                  ],
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('是否仍在使用'),
                  value: _stillUsing,
                  onChanged: (v) => setState(() => _stillUsing = v),
                ),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '文字评价（可选，勿写病历）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(onPressed: _save, child: const Text('保存评价')),
                const SizedBox(height: 20),
                const Text('社区聚合（需联网）',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          labelText: '查药品社区评价',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _loadSummary(_searchCtrl.text.trim()),
                      child: const Text('查询'),
                    ),
                  ],
                ),
                if (_summary != null)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${_summary!['drugName']} · 均分 ${_summary!['avgEfficacy']}'
                        '（${_summary!['count']} 条）',
                      ),
                      subtitle: Text(
                        '副作用分布：${(_summary!['seDist'] as List?)?.join('/') ?? '—'}',
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text('我的评价',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (_rows.isEmpty)
                  const Text('暂无评价',
                      style: TextStyle(color: IbdColors.textSecondary)),
                ..._rows.map((r) {
                  return Card(
                    child: ListTile(
                      dense: true,
                      title: Text(
                        '${r['drug_name']} · ${r['efficacy']} 星',
                      ),
                      subtitle: Text(
                        '${r['ibd_type'] ?? ''} · 副作用'
                        '${['无', '轻', '中', '重'][(r['se_side_effect'] as num?)?.toInt() ?? 0]}'
                        '${r['comment'] == null ? '' : ' · ${r['comment']}'}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          await _repo.delete('${r['id']}');
                          await _load();
                        },
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                const Text(
                  '社区聚合需联网并由服务端统计；本页先展示「我的评价」。',
                  style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
                ),
              ],
            ),
    );
  }
}
