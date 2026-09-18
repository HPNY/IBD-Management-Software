import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/ui/theme.dart';
import '../injection/injection_page.dart';
import 'medication_checkin_page.dart';
import 'medication_edit_page.dart';

/// 用药管理：注射药品 + 日常用药 + 历史时间轴
class MedicationPage extends StatefulWidget {
  const MedicationPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<MedicationPage> createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  final _meds = MedicationRepository();
  final _inj = InjectionRepository();

  List<Map<String, dynamic>> _injections = [];
  List<Map<String, dynamic>> _currentMeds = [];
  List<Map<String, dynamic>> _history = [];
  bool _busy = false;
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
      final inj = await _inj.listAll();
      final pending = await _inj.listPending(withinDays: 365);
      final current = await _meds.listCurrent();
      final all = await _meds.listAll();
      if (!mounted) return;
      setState(() {
        _injections = pending.isNotEmpty ? pending : inj.take(8).toList();
        _currentMeds = current;
        _history = all;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? initial]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MedicationEditPage(initial: initial),
      ),
    );
    if (ok == true || ok == null) await _load();
  }

  Future<void> _stop(Map<String, dynamic> med) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('停用该日常用药？'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(hintText: '原因（可选）'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('停用')),
        ],
      ),
    );
    if (ok != true) return;
    await _meds.stop(med['id'] as String, reason: reason.text.trim());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final injDrugs = <String, Map<String, dynamic>>{};
    for (final r in _injections) {
      final name = '${r['drug']}';
      final last = injDrugs[name];
      final planned = '${r['planned_date']}';
      if (last == null || planned.compareTo('${last['planned_date']}') < 0) {
        injDrugs[name] = r;
      }
    }

    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('用药管理'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加用药'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            // —— 注射 / 生物制剂（来自注射排期）——
            _SectionHeader(
              title: '注射用药',
              subtitle: '来自「注射排期」的药品',
              trailing: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InjectionPage()),
                  );
                },
                child: const Text('去排期'),
              ),
            ),
            if (injDrugs.isEmpty)
              _EmptyHint(
                text: '暂无注射计划',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InjectionPage()),
                  );
                },
              )
            else
              ...injDrugs.values.map((r) => _InjectionCard(row: r)),

            const SizedBox(height: 20),

            // —— 当前日常用药 ——
            _SectionHeader(
              title: '当前用药',
              subtitle: '${_currentMeds.length} 项（口服/其他）',
              trailing: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MedicationCheckinPage(),
                    ),
                  );
                },
                child: const Text('服药打卡'),
              ),
            ),
            if (_currentMeds.isEmpty)
              const _EmptyHint(text: '可点右下角添加日常用药'),
            ..._currentMeds.map(
              (m) => _DailyMedCard(
                med: m,
                onEdit: () => _openEditor(m),
                onStop: () => _stop(m),
              ),
            ),

            const SizedBox(height: 20),

            // —— 历史时间轴 ——
            const _SectionHeader(title: '用药历史', subtitle: '按开始时间'),
            if (_history.isEmpty)
              const _EmptyHint(text: '历史记录会出现在这里'),
            ..._history.asMap().entries.map((e) {
              final m = e.value;
              final last = e.key == _history.length - 1;
              final stopped = m['status'] == 'stopped';
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: stopped
                              ? const Color(0xFFE2E8F0)
                              : IbdColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          stopped ? Icons.stop_rounded : Icons.medication_rounded,
                          size: 14,
                          color: stopped
                              ? IbdColors.textSecondary
                              : IbdColors.primary,
                        ),
                      ),
                      if (!last)
                        Container(
                          width: 2,
                          height: 28,
                          color: const Color(0xFFE2E8F0),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(bottom: last ? 0 : 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: IbdColors.card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m['drug_name']} ${m['dosage']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${m['frequency'] ?? ''} · ${m['start_date']}'
                            '${m['end_date'] != null ? ' → ${m['end_date']}' : ' → 至今'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: IbdColors.textSecondary,
                            ),
                          ),
                          if (m['reason'] != null && '${m['reason']}'.isNotEmpty)
                            Text(
                              '${m['reason']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: IbdColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(color: IbdColors.danger)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: IbdColors.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: IbdColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: IbdColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: const TextStyle(color: IbdColors.textSecondary)),
      ),
    );
  }
}

class _InjectionCard extends StatelessWidget {
  const _InjectionCard({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final done = row['actual_date'] != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IbdColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.vaccines_rounded,
                color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row['drug']}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  '下次/最近计划 ${row['planned_date']}'
                  '${done ? ' · 已完成' : ' · 待注射'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: IbdColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: IbdColors.textSecondary),
        ],
      ),
    );
  }
}

class _DailyMedCard extends StatelessWidget {
  const _DailyMedCard({
    required this.med,
    required this.onEdit,
    required this.onStop,
  });

  final Map<String, dynamic> med;
  final VoidCallback onEdit;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: IbdColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication_liquid_rounded,
                    color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${med['drug_name']} ${med['dosage']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${med['frequency'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: IbdColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onEdit, child: const Text('编辑')),
              TextButton(
                onPressed: onStop,
                child: const Text('停用',
                    style: TextStyle(color: IbdColors.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
