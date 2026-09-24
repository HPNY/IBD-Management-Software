import 'package:flutter/material.dart';

import '../../core/activity/activity_service.dart';
import '../../core/db/repositories.dart';
import '../../core/ui/theme.dart';
import '../medication/medication_page.dart';

/// G1 疾病活动度详情页（PRD §2.6.1）：
/// 炎症三联状态灯 · Limberg/SES-CD 趋势 · 当前用药卡 · 注射倒计时。
class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({super.key});

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  final _labs = LabRepository();
  final _meds = MedicationRepository();
  final _inj = InjectionRepository();
  final _exams = ExamRepository();

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
          items.any((e) => e is Map && '${e['nameNorm']}' == nameNorm)) {
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

  Color _lightColor(String light) {
    switch (light) {
      case 'red':
        return IbdColors.danger;
      case 'green':
        return IbdColors.success;
      default:
        return const Color(0xFFCBD5E1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
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
                              child: Column(
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: _lightColor(t.light),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    t.label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.value ?? '—',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: t.light == 'red'
                                          ? IbdColors.danger
                                          : IbdColors.textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    t.date ?? '暂无数据',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: IbdColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Card(
                    title: '下次注射倒计时',
                    child: Row(
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
                                  ? IbdColors.textSecondary
                                  : (_daysToNext! <= 3
                                      ? IbdColors.warning
                                      : IbdColors.primaryDark),
                            ),
                          ),
                        ),
                        if (_pendingInj.isNotEmpty)
                          Text(
                            '${_pendingInj.first['drug'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: IbdColors.textSecondary,
                            ),
                          ),
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
                        ? const Text(
                            '暂无在用药物',
                            style: TextStyle(color: IbdColors.textSecondary),
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
                                          '${m['drugName'] ?? ''} '
                                          '${m['dosage'] ?? ''}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${m['frequency'] ?? ''} · ${m['status'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: IbdColors.textSecondary,
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
        color: IbdColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: IbdColors.textSecondary,
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
              style: const TextStyle(
                fontSize: 12.5,
                color: IbdColors.textSecondary,
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
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: IbdColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          r.value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: IbdColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (rows.length > 8)
                  Text(
                    '仅显示最近 8 条 · 共 ${rows.length} 条',
                    style: const TextStyle(
                      fontSize: 11,
                      color: IbdColors.textSecondary,
                    ),
                  ),
              ],
            ),
    );
  }
}
