import 'package:flutter/material.dart';

import '../../core/ai/ai_rules.dart';
import '../../core/db/repositories.dart';
import '../../core/ui/theme.dart';

/// D4：AI/规则辅助分析（本地统计，仅供参考，非诊断）。
class AiRulesPage extends StatefulWidget {
  const AiRulesPage({
    super.key,
    this.labs,
    this.symptoms,
    this.meds,
  });

  final LabSeriesRepository? labs;
  final SymptomRepository? symptoms;
  final MedicationRepository? meds;

  @override
  State<AiRulesPage> createState() => _AiRulesPageState();
}

class _AiRulesPageState extends State<AiRulesPage> {
  late final LabSeriesRepository _labs = widget.labs ?? LabSeriesRepository();
  late final SymptomRepository _sym = widget.symptoms ?? SymptomRepository();
  late final MedicationRepository _meds = widget.meds ?? MedicationRepository();

  final List<MetricTrend> _trends = [];
  final List<AiAlert> _alerts = [];
  final List<MedDelta> _medDeltas = [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      const metrics = [
        '超敏C反应蛋白',
        '血沉',
        '粪便钙卫蛋白',
      ];
      _trends.clear();
      _alerts.clear();
      _medDeltas.clear();

      for (final name in metrics) {
        final rows = await _labs.seriesByName(name);
        final values = <double>[];
        final dates = <String>[];
        for (final r in rows) {
          final v = (r['value'] as num?)?.toDouble();
          if (v == null) continue;
          values.add(v);
          dates.add('${r['date']}');
        }
        if (values.isEmpty) continue;
        _trends.add(summarizeSeries(name: name, values: values, dates: dates));
        _alerts.addAll(labConsecutiveRise(name: name, values: values));

        final meds = await _meds.listAll();
        for (final m in meds) {
          final drug = '${m['drug_name'] ?? ''}';
          final start = '${m['start_date'] ?? ''}';
          if (drug.isEmpty || start.isEmpty || start == 'null') continue;
          final delta = medBeforeAfter(
            drugName: drug,
            metric: name,
            labDates: dates,
            labValues: values,
            start: start,
          );
          if (delta != null) _medDeltas.add(delta);
        }
      }

      final diaries = await _sym.listAll();
      final bloodFlags = <bool>[];
      final bloodDates = <String>[];
      final stool = <double>[];
      // listAll 为 date DESC → 反转为升序
      final asc = diaries.reversed.toList();
      for (final d in asc) {
        final bloody = '${d['bloody_stool'] ?? ''}';
        bloodDates.add('${d['date']}');
        bloodFlags.add(bloody == 'trace' || bloody == 'obvious');
        final c = (d['bowel_count'] as num?)?.toDouble() ??
            (d['diarrhea_count'] as num?)?.toDouble();
        stool.add(c ?? 0);
      }
      _alerts.addAll(
        bloodStreak(dates: bloodDates, hasBlood: bloodFlags, days: 2),
      );
      _alerts.addAll(stoolSurge(dailyCounts: stool));

      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(
        title: const Text('AI / 规则分析'),
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
                  '本机规则统计，不能替代医生诊断。',
                  style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
                ),
                if (_error != null)
                  Text('加载失败：$_error',
                      style: const TextStyle(color: IbdColors.danger)),
                const SizedBox(height: 12),
                const Text('指标趋势',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (_trends.isEmpty)
                  const Text('暂无检验序列，可先录入检验',
                      style: TextStyle(color: IbdColors.textSecondary)),
                ..._trends.map(
                  (t) => Card(
                    child: ListTile(
                      dense: true,
                      title: Text('${t.name} · ${t.label}'),
                      subtitle: Text(
                        '点数 ${t.points} · 最近 ${t.last?.toStringAsFixed(1) ?? '—'}'
                        '${t.avg30 != null ? ' · 30点均 ${t.avg30!.toStringAsFixed(1)}' : ''}'
                        '${t.avg90 != null ? ' · 90点均 ${t.avg90!.toStringAsFixed(1)}' : ''}',
                      ),
                      trailing: Icon(
                        t.direction == TrendDirection.rising
                            ? Icons.trending_up_rounded
                            : t.direction == TrendDirection.falling
                                ? Icons.trending_down_rounded
                                : Icons.trending_flat_rounded,
                        color: t.direction == TrendDirection.rising
                            ? IbdColors.warning
                            : t.direction == TrendDirection.falling
                                ? IbdColors.success
                                : IbdColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('异常提示',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (_alerts.isEmpty)
                  const Text('未触发规则',
                      style: TextStyle(color: IbdColors.textSecondary)),
                ..._alerts.map(
                  (a) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(a.detail, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('用药前后检验对比',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (_medDeltas.isEmpty)
                  const Text('暂无足够检验点做前后对比',
                      style: TextStyle(color: IbdColors.textSecondary)),
                ..._medDeltas.map(
                  (m) => Card(
                    child: ListTile(
                      dense: true,
                      title: Text('${m.drugName} · ${m.metric}'),
                      subtitle: Text(
                        '用药前均 ${m.beforeAvg.toStringAsFixed(1)}（${m.beforeN} 次）'
                        ' → 后 ${m.afterAvg.toStringAsFixed(1)}（${m.afterN} 次）'
                        ' · ${m.changePct >= 0 ? '+' : ''}${m.changePct.toStringAsFixed(0)}%',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '规则仅供参考；不自动外发、不推送云端。LLM 总结默认关闭（未启用）。',
                  style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
                ),
              ],
            ),
    );
  }
}
