import 'package:flutter/material.dart';

import '../../core/activity/activity_service.dart';
import '../../core/db/repositories.dart';
import '../../core/ui/disclaimer.dart';
import '../../core/ui/cards.dart';
import '../../core/ui/theme.dart';
import '../injection/injection_page.dart';
import '../medication/medication_page.dart';

/// G1 疾病活动度详情页（PRD §2.6.1）：
/// 炎症三联状态灯 · Limberg/SES-CD 趋势 · 当前用药卡 · 注射倒计时。
class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({
    super.key,
    this.labRepo,
    this.medRepo,
    this.injRepo,
    this.examRepo,
  });

  /// 测试可注入仓库。
  final LabRepository? labRepo;
  final MedicationRepository? medRepo;
  final InjectionRepository? injRepo;
  final ExamRepository? examRepo;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late final _labs = widget.labRepo ?? LabRepository();
  late final _meds = widget.medRepo ?? MedicationRepository();
  late final _inj = widget.injRepo ?? InjectionRepository();
  late final _exams = widget.examRepo ?? ExamRepository();

  List<Map<String, dynamic>> _labRows = [];
  List<Map<String, dynamic>> _medsNow = [];
  List<Map<String, dynamic>> _pendingInj = [];
  List<Map<String, dynamic>> _examsAll = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final labs = await _labs.listAll();
      final meds = await _meds.listCurrent();
      final inj = await _inj.listPending(withinDays: 60);
      final exams = await _exams.listAll();
      if (!mounted) return;
      setState(() {
        _labRows = labs;
        _medsNow = meds;
        _pendingInj = inj;
        _examsAll = exams;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  ({String label, String? value, String? date, String light}) _trio(
    String nameNorm,
    String label,
  ) {
    final item = latestLabItem(_labRows, nameNorm);
    if (item == null) {
      return (label: label, value: null, date: null, light: 'gray');
    }
    // 找到 item 所在 lab 的日期
    String? date;
    for (final lab in _labRows) {
      final items = lab['items'];
      if (items is List &&
          items.any((e) => e is Map && '${e['nameNorm'] ?? e['name_norm']}' == nameNorm)) {
        date = '${lab['date']}';
        break;
      }
    }
    return (
      label: label,
      value: '${item['value']}${item['unit'] == null ? '' : ' ${item['unit']}'}',
      date: date,
      light: inflammationLight(item['flag'] as String?),
    );
  }

  List<({String date, String value})> _limbergSeries() {
    final out = <({String date, String value})>[];
    for (final e in _examsAll) {
      final v = extractLimberg(e['score'] as String?, e['findings'] as String?);
      if (v != null) out.add((date: '${e['date']}', value: v));
    }
    return out;
  }

  List<({String date, String value})> _sesSeries() {
    final out = <({String date, String value})>[];
    for (final e in _examsAll) {
      final v = extractSesCd(e['score'] as String?, e['findings'] as String?);
      if (v != null) out.add((date: '${e['date']}', value: v));
    }
    return out;
  }

  int? get _daysToNext {
    if (_pendingInj.isEmpty) return null;
    final sorted = [..._pendingInj]
      ..sort((a, b) =>
          '${a['planned_date']}'.compareTo('${b['planned_date']}'));
    return daysUntilInjection('${sorted.first['planned_date']}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ibd.bg,
      appBar: AppBar(title: const Text('疾病活动度')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _Card(
                    title: '炎症三联状态灯',
                    subtitle: '最近一次检验 · 按参考范围',
                    child: Row(
                      children: [
                        for (final t in [
                          _trio('超敏C反应蛋白', 'CRP'),
                          _trio('血沉', 'ESR'),
                          _trio('粪便钙卫蛋白', '钙卫'),
                        ])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              // U6：与首页三灯同一个组件。原来这里只有圆点颜色，
                              // 没有「偏高/正常/未测」文字——色盲下信息全丢（WCAG 1.4.1）
                              child: IbdMetric.status(
                                label: t.label,
                                value: t.value ?? '—',
                                state: inflammationStateText(t.light),
                                caption: t.date ?? '暂无数据',
                                tone: IbdMetricTone.ofLight(t.light),
                                dotSize: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Card(
                    title: '下次注射倒计时',
                    trailing: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InjectionPage(),
                        ),
                      ),
                      child: const Text('排期'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _daysToNext == null
                                    ? '无待打针'
                                    : _daysToNext! < 0
                                        ? '已逾期 ${-_daysToNext!} 天'
                                        : _daysToNext == 0
                                            ? '今天该打'
                                            : '还有 ${_daysToNext!} 天',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _daysToNext == null
                                      ? context.ibd.textSecondary
                                      : (_daysToNext! <= 3
                                          ? context.ibd.warning
                                          : context.ibd.brandInk),
                                ),
                              ),
                            ),
                            if (_pendingInj.isNotEmpty)
                              Text(
                                '${_pendingInj.first['drug'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.ibd.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        if (_pendingInj.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          for (final row in _pendingInj.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '· ${row['planned_date'] ?? ''} '
                                '${row['drug'] ?? ''} ${row['dose'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: context.ibd.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ScoreTrendCard(
                    title: 'Limberg 分级趋势（超声）',
                    emptyHint: '暂无 Limberg 记录（在检查的评分字段填写 Limberg II 等）',
                    rows: _limbergSeries(),
                  ),
                  const SizedBox(height: 14),
                  _ScoreTrendCard(
                    title: 'SES-CD 评分趋势（内镜）',
                    emptyHint: '暂无 SES-CD 记录（在检查的评分字段填写 SES-CD 12 等）',
                    rows: _sesSeries(),
                  ),
                  const SizedBox(height: 14),
                  _Card(
                    title: '当前用药方案',
                    trailing: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MedicationPage()),
                      ),
                      child: const Text('管理'),
                    ),
                    child: _medsNow.isEmpty
                        ? Text(
                            '暂无在用药物',
                            style: TextStyle(color: context.ibd.textSecondary),
                          )
                        : Column(
                            children: [
                              for (final m in _medsNow)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${(m['drugName'] ?? m['drug_name']) ?? ''} '
                                          '${m['dosage'] ?? ''}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${m['frequency'] ?? ''} · ${m['status'] ?? ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.ibd.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: context.ibd.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.ibd.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.ibd.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ScoreTrendCard extends StatelessWidget {
  const _ScoreTrendCard({
    required this.title,
    required this.emptyHint,
    required this.rows,
  });

  final String title;
  final String emptyHint;
  final List<({String date, String value})> rows;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: title,
      child: rows.isEmpty
          ? Text(
              emptyHint,
              style: TextStyle(
                fontSize: 12.5,
                color: context.ibd.textSecondary,
                height: 1.4,
              ),
            )
          : Column(
              children: [
                for (final r in rows.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text(
                          r.date,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.ibd.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          r.value,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: context.ibd.brandInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (rows.length > 8)
                  Text(
                    '仅显示最近 8 条 · 共 ${rows.length} 条',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.ibd.textSecondary,
                    ),
                  ),
                // T7：非诊断/非治疗声明
                const DisclaimerFooter(),
              ],
            ),
    );
  }
}
