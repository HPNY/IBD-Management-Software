import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/ui/theme.dart';

/// 服药打卡日历：按药按日勾选早/午/晚/夜
class MedicationCheckinPage extends StatefulWidget {
  const MedicationCheckinPage({super.key});

  @override
  State<MedicationCheckinPage> createState() => _MedicationCheckinPageState();
}

class _MedicationCheckinPageState extends State<MedicationCheckinPage> {
  final _meds = MedicationRepository();
  final _ck = MedicationCheckinRepository();

  List<Map<String, dynamic>> _currentMeds = [];
  String? _medId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selected = DateTime.now();
  Set<String> _todaySlots = {};
  Map<String, int> _heat = {};
  bool _busy = false;

  static const slotLabels = {
    'morning': '早',
    'noon': '午',
    'evening': '晚',
    'night': '夜',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final meds = await _meds.listCurrent();
      if (!mounted) return;
      setState(() {
        _currentMeds = meds;
        if (_medId == null && meds.isNotEmpty) {
          _medId = meds.first['id'] as String;
        }
      });
      await _reloadDay();
      final heat = await _ck.takenCountByDate(days: 120);
      if (mounted) setState(() => _heat = heat);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reloadDay() async {
    if (_medId == null) {
      setState(() => _todaySlots = {});
      return;
    }
    final iso = _iso(_selected);
    final slots = await _ck.slotsForDate(_medId!, iso);
    final heat = await _ck.takenCountByDate(days: 120);
    if (!mounted) return;
    setState(() {
      _todaySlots = slots;
      _heat = heat;
    });
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _toggleSlot(String slot) async {
    if (_medId == null) return;
    final iso = _iso(_selected);
    if (_todaySlots.contains(slot)) {
      await _ck.unmark(medicationId: _medId!, date: iso, slot: slot);
    } else {
      await _ck.markTaken(medicationId: _medId!, date: iso, slot: slot);
    }
    await _reloadDay();
  }

  @override
  Widget build(BuildContext context) {
    final month = _month;
    final first = DateTime(month.year, month.month, 1);
    final startWd = first.weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(title: const Text('服药打卡')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_currentMeds.isEmpty)
            const Card(
              child: ListTile(
                title: Text('暂无当前用药'),
                subtitle: Text('请先在「用药管理」添加日常用药'),
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _medId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '选择药品'),
              items: _currentMeds
                  .map(
                    (m) => DropdownMenuItem(
                      value: m['id'] as String,
                      child: Text(
                        '${m['drug_name']} ${m['dosage']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => _medId = v);
                _reloadDay();
              },
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: IbdColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.04)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() {
                        _month = DateTime(month.year, month.month - 1, 1);
                      }),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${month.year} 年 ${month.month} 月',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        _month = DateTime(month.year, month.month + 1, 1);
                      }),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    _Dow('日'),
                    _Dow('一'),
                    _Dow('二'),
                    _Dow('三'),
                    _Dow('四'),
                    _Dow('五'),
                    _Dow('六'),
                  ],
                ),
                const SizedBox(height: 6),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 7,
                  childAspectRatio: 0.9,
                  children: [
                    for (var i = 0; i < startWd; i++) const SizedBox(),
                    for (var d = 1; d <= days; d++)
                      Builder(builder: (context) {
                        final date = DateTime(month.year, month.month, d);
                        final iso = _iso(date);
                        final count = _heat[iso] ?? 0;
                        final selected = _iso(_selected) == iso;
                        final isToday = date.year == today.year &&
                            date.month == today.month &&
                            date.day == today.day;
                        return InkWell(
                          onTap: () {
                            setState(() => _selected = date);
                            _reloadDay();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: selected
                                  ? IbdColors.primary
                                  : (count > 0
                                      ? IbdColors.primary.withOpacity(0.15)
                                      : null),
                              border: Border.all(
                                color: isToday && !selected
                                    ? IbdColors.primary
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$d',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: selected
                                        ? Colors.white
                                        : IbdColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  count > 0 ? '$count' : '',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: selected
                                        ? Colors.white70
                                        : IbdColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '深色为选中日期；浅色数字为当日已打卡次数',
                  style: TextStyle(fontSize: 11, color: IbdColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_iso(_selected)} 打卡',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_medId == null)
            const Text('请选择药品', style: TextStyle(color: IbdColors.textSecondary))
          else
            ...slotLabels.entries.map((e) {
              final taken = _todaySlots.contains(e.key);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: taken,
                  onChanged: (_) => _toggleSlot(e.key),
                  title: Text(
                    e.value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(taken ? '已服用' : '未打卡'),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: IbdColors.primary,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Dow extends StatelessWidget {
  const _Dow(this.t);
  final String t;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          color: IbdColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
