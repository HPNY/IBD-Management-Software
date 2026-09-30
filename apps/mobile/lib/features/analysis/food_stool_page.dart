import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/food/food_stool_link.dart';
import '../../core/ui/theme.dart';

/// G6：食物标签日志 + 食物-排便关联分析入口（本机数据，非诊断）。
class FoodStoolPage extends StatefulWidget {
  const FoodStoolPage({super.key, this.foodRepo, this.symptomRepo});

  final FoodRepository? foodRepo;
  final SymptomRepository? symptomRepo;

  @override
  State<FoodStoolPage> createState() => _FoodStoolPageState();
}

class _FoodStoolPageState extends State<FoodStoolPage> {
  late final FoodRepository _food = widget.foodRepo ?? FoodRepository();
  late final SymptomRepository _sym = widget.symptomRepo ?? SymptomRepository();

  final _tagCtrl = TextEditingController();
  String _meal = '午餐';
  List<Map<String, dynamic>> _logs = [];
  List<FoodStoolLink> _links = [];
  bool _busy = false;

  static const meals = ['早餐', '午餐', '晚餐', '加餐'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final logs = await _food.listAll();
      final foods = <FoodLogEntry>[
        for (final r in logs)
          FoodLogEntry(
            date: '${r['date']}',
            tags: parseFoodTags('${r['foods']}'),
            meal: r['meal'] as String?,
          ),
      ];
      final symptoms = await _sym.listAll();
      final stool = <String, StoolDay>{};
      for (final s in symptoms) {
        final date = '${s['date']}';
        final count = (s['bowel_count'] as num?)?.toInt() ??
            (s['diarrhea_count'] as num?)?.toInt();
        final type = (s['stool_type'] as num?)?.toInt();
        final bloody = s['bloody_stool'] as String?;
        if (count == null && type == null && bloody == null) continue;
        stool[date] = StoolDay(
          diarrheaCount: count,
          stoolType: type,
          bloodyStool: bloody,
        );
      }
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _links = foodStoolLinks(foods: foods, stoolByDate: stool);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final text = _tagCtrl.text.trim();
    if (text.isEmpty) return;
    final n = DateTime.now();
    final date =
        '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    await _food.insert(date: date, foods: text, meal: _meal);
    _tagCtrl.clear();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已记录：$date $_meal · $text')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(
        title: const Text('食物与排便'),
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
                  '记录今天吃了什么',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text(
                  '用逗号分隔食物标签，例如：牛奶、辣火锅、冷饮。仅保存在本机，用于自我观察。',
                  style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final m in meals)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(m, style: const TextStyle(fontSize: 12)),
                          selected: _meal == m,
                          onSelected: (_) => setState(() => _meal = m),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tagCtrl,
                  decoration: InputDecoration(
                    hintText: '牛奶、辣火锅、冷饮…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                ),
                const SizedBox(height: 8),
                FilledButton(onPressed: _add, child: const Text('记一笔')),
                const SizedBox(height: 20),
                const Text(
                  '食物 × 排便关联（观察用，非因果）',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text(
                  '对比「吃过该标签的排便日」与「未吃该标签的日子」：腹泻率（次数≥3 或 Bristol≥6）、便血率、平均次数。样本少时仅供参考。',
                  style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
                ),
                const SizedBox(height: 10),
                if (_links.isEmpty)
                  const Text(
                    '暂无分析：先记录食物，并完成症状打卡/排便细表',
                    style: TextStyle(color: IbdColors.textSecondary),
                  ),
                ..._links.map((l) {
                  final dDelta = l.diarrheaRateEaten - l.diarrheaRateBase;
                  final bDelta = l.bloodRateEaten - l.bloodRateBase;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l.tag,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (l.suspiciousDiarrhea)
                                const Chip(
                                  label: Text('腹泻偏高',
                                      style: TextStyle(fontSize: 11)),
                                ),
                              if (l.suspiciousBlood)
                                const Chip(
                                  label: Text('便血偏高',
                                      style: TextStyle(fontSize: 11)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '吃过 ${l.daysEaten} 天 · 腹泻 ${(l.diarrheaRateEaten * 100).round()}%'
                            '（对照 ${(l.diarrheaRateBase * 100).round()}%）'
                            ' · 便血 ${(l.bloodRateEaten * 100).round()}%'
                            '（对照 ${(l.bloodRateBase * 100).round()}%）',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          Text(
                            '平均排便 ${l.avgCountEaten.toStringAsFixed(1)} 次'
                            '（对照 ${l.avgCountBase.toStringAsFixed(1)}）'
                            '${dDelta > 0 ? ' · 腹泻差 +${(dDelta * 100).round()}pp' : ''}'
                            '${bDelta > 0 ? ' · 便血差 +${(bDelta * 100).round()}pp' : ''}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: IbdColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                const Text('今日食物记录',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (_logs.isEmpty)
                  const Text('暂无记录',
                      style: TextStyle(color: IbdColors.textSecondary)),
                ..._logs.map((r) {
                  return Card(
                    child: ListTile(
                      dense: true,
                      title: Text('${r['foods']}'),
                      subtitle: Text('${r['date']} · ${r['meal'] ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          await _food.delete('${r['id']}');
                          await _load();
                        },
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                const Text(
                  '仅供自我记录与就医沟通参考，不能替代医生或营养师诊断。',
                  style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
                ),
              ],
            ),
    );
  }
}
