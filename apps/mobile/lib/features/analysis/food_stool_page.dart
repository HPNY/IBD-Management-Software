import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/food/food_dictionary.dart';
import '../../core/food/food_nutrition.dart';
import '../../core/food/food_stool_link.dart';
import '../../core/ui/theme.dart';

/// G6+D1：食物标签日志、营养粗记、词典/食谱、排便关联（本机数据，非诊断）。
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
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  String _meal = '午餐';
  List<Map<String, dynamic>> _logs = [];
  List<FoodStoolLink> _links = [];
  bool _busy = false;
  String _dictQuery = '';

  static const meals = ['早餐', '午餐', '晚餐', '加餐'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    super.dispose();
  }

  String get _today {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
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

  Future<void> _add({String? overrideFoods}) async {
    final text = (overrideFoods ?? _tagCtrl.text).trim();
    if (text.isEmpty) return;
    final kcal = double.tryParse(_kcalCtrl.text.trim());
    final protein = double.tryParse(_proteinCtrl.text.trim());
    await _food.insert(
      date: _today,
      foods: text,
      meal: _meal,
      calories: kcal,
      proteinG: protein,
    );
    if (overrideFoods == null) _tagCtrl.clear();
    _kcalCtrl.clear();
    _proteinCtrl.clear();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已记录：$_today $_meal · $text')),
      );
    }
  }

  void _toggleDictTag(String label) {
    final merged = mergeFoodTags(_tagCtrl.text, [label]);
    _tagCtrl.text = merged;
  }

  List<FoodNutritionRow> get _nutritionRows {
    return [
      for (final r in _logs)
        FoodNutritionRow(
          date: '${r['date']}',
          calories: (r['calories'] as num?)?.toDouble(),
          proteinG: (r['protein_g'] as num?)?.toDouble(),
          foods: parseFoodTags('${r['foods']}'),
        ),
    ];
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _kcalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '热量 kcal（可空）',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _proteinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '蛋白 g（可空）',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton(onPressed: _add, child: const Text('记一笔')),
                const SizedBox(height: 12),
                const Text('营养粗记汇总（自管参考）',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 6),
                Builder(builder: (context) {
                  final rows = _nutritionRows;
                  final today = summarizeDay(_today, rows);
                  final avg = averageRecent(rows, _today, 7);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        today.hasData
                            ? '今日 · ${today.calories.toStringAsFixed(0)} kcal · 蛋白 ${today.proteinG.toStringAsFixed(0)} g'
                            : '今日未记录营养',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      Text(
                        '近 7 日 · 均 ${avg.avgKcal.toStringAsFixed(0)} kcal / ${avg.avgProtein.toStringAsFixed(0)} g 蛋白'
                        '（有记录 ${avg.daysWithKcal} / ${avg.daysWithProtein} 天）',
                        style: const TextStyle(
                          fontSize: 12,
                          color: IbdColors.textSecondary,
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                const Text('词典点选',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 6),
                TextField(
                  decoration: InputDecoration(
                    hintText: '筛选食物 / 类别…',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (v) => setState(() => _dictQuery = v),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in searchFoodDict(_dictQuery))
                      ActionChip(
                        label: Text(
                          d.note != null ? '${d.label} · ${d.note}' : d.label,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        onPressed: () => setState(() => _toggleDictTag(d.label)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('食谱参考（一键记入标签，非处方）',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 6),
                ...kDietRecipes.map(
                  (r) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (r.description != null)
                            Text(
                              r.description!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: IbdColors.textSecondary,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text('标签：${r.tags.join('、')}',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () {
                              final merged =
                                  mergeFoodTags(_tagCtrl.text, r.tags);
                              _tagCtrl.text = merged;
                              // D1.4：一键写入当日 food_logs
                              void _write() => _add(overrideFoods: merged);
                              _write();
                            },
                            child: const Text('一键记入今日'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
