import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/injection/drug_catalog.dart';
import '../../core/notify/local_notify.dart';
import '../../core/ui/theme.dart';

/// 注射排期：两级药品 + 起始日 + 间隔（天/周）+ 日历标注
class InjectionPage extends StatefulWidget {
  const InjectionPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<InjectionPage> createState() => _InjectionPageState();
}

class _InjectionPageState extends State<InjectionPage> {
  final _repo = InjectionRepository();
  final _startCtrl = TextEditingController();
  final _intervalCtrl = TextEditingController(text: '8');

  String _categoryKey = kDrugCatalog.first.key;
  String _brand = kDrugCatalog.first.brands.first.brand;
  String _unit = 'weeks';
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Set<String> _plannedIso = {};
  List<Map<String, dynamic>> _rows = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cat = kDrugCatalog.first;
    _unit = cat.defaultUnit;
    _intervalCtrl.text = '${cat.defaultInterval}';
    final n = DateTime.now();
    _startCtrl.text = isoDate(n);
    _rebuildPreview();
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  DrugCategory get _category =>
      findDrugCategory(_categoryKey) ?? kDrugCatalog.first;

  void _onCategoryChanged(String? key) {
    if (key == null) return;
    final cat = findDrugCategory(key)!;
    setState(() {
      _categoryKey = key;
      _brand = cat.brands.first.brand;
      _unit = cat.defaultUnit;
      _intervalCtrl.text = '${cat.defaultInterval}';
    });
    _rebuildPreview();
  }

  void _rebuildPreview() {
    final start = DateTime.tryParse(_startCtrl.text.trim());
    final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 0;
    if (start == null || interval <= 0) {
      setState(() => _plannedIso = {});
      return;
    }
    final dates = buildIntervalDates(
      start: start,
      interval: interval,
      unit: _unit,
      maxCount: 36,
    );
    setState(() {
      _plannedIso = dates.map(isoDate).toSet();
      _calendarMonth = DateTime(start.year, start.month, 1);
    });
  }

  Future<void> _pickStart() async {
    final init = DateTime.tryParse(_startCtrl.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    _startCtrl.text = isoDate(picked);
    _rebuildPreview();
  }

  Future<void> _generate() async {
    final start = DateTime.tryParse(_startCtrl.text.trim());
    final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 0;
    if (start == null || interval <= 0) {
      setState(() => _error = '请填写合法的起始日期与间隔');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dates = buildIntervalDates(
        start: start,
        interval: interval,
        unit: _unit,
        maxCount: 24,
      );
      final cat = _category;
      final drugLabel = '${cat.genericName}（$_brand）';
      // 旧计划先清空同药名未完成针次
      await _repo.clearPendingForDrug(drugLabel);
      await _repo.insertMany([
        for (var i = 0; i < dates.length; i++)
          {
            'drug': drugLabel,
            'plannedDate': isoDate(dates[i]),
            'phase': i == 0 && dates.length > 1 ? 'induction' : 'maintenance',
            'dose': _unit == 'weeks' && interval >= 6 ? '维持' : '按方案',
            'route': cat.key == 'upadacitinib' ? 'oral' : 'sc',
            'weekNumber': i,
            'notes': '${cat.mechanism} · 每 $interval $_unit',
          },
      ]);
      final pending = await _repo.listPending(withinDays: 120);
      final rows = await _repo.listAll();
      await LocalNotifyService.instance.scheduleInjectionReminders(pending);
      if (!mounted) return;
      setState(() => _rows = rows);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已生成 $drugLabel：每 $interval ${_unit == 'weeks' ? '周' : '天'}，共 ${dates.length} 次',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadRows() async {
    final rows = await _repo.listAll();
    if (mounted) setState(() => _rows = rows);
  }

  Future<void> _complete(Map<String, dynamic> row) async {
    await _repo.complete(row['id'] as String);
    await _loadRows();
  }

  @override
  Widget build(BuildContext context) {
    final cat = _category;
    final brands = cat.brands;

    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('注射排期'),
        actions: [
          IconButton(onPressed: _busy ? null : _loadRows, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadRows(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: IbdColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '生成排期',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cat.mechanism,
                    style: const TextStyle(
                      fontSize: 12,
                      color: IbdColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('药品大类（通用名）', style: _label),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryKey,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: '选择通用名',
                    ),
                    items: kDrugCatalog
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.key,
                            child: Text(
                              '${c.genericName}（${c.mechanism}）',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _onCategoryChanged,
                  ),
                  const SizedBox(height: 12),
                  const Text('商品名', style: _label),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _brand,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: '选择商品名',
                    ),
                    items: brands
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.brand,
                            child: Text(
                              b.note == null ? b.brand : '${b.brand}（${b.note}）',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _brand = v ?? _brand),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startCtrl,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: '起始日期',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today_outlined),
                              onPressed: _pickStart,
                            ),
                          ),
                          onTap: _pickStart,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('给药间隔', style: _label),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _intervalCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '每隔'),
                          onChanged: (_) => _rebuildPreview(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          initialValue: _unit,
                          decoration: const InputDecoration(labelText: '单位'),
                          items: const [
                            DropdownMenuItem(value: 'days', child: Text('天')),
                            DropdownMenuItem(value: 'weeks', child: Text('周')),
                          ],
                          onChanged: (v) {
                            setState(() => _unit = v ?? 'weeks');
                            _rebuildPreview();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '例：每隔 8 周打一次；或每隔 14 天。默认值来自所选药品。',
                    style: TextStyle(
                      fontSize: 12,
                      color: IbdColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _busy ? null : _generate,
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text(_busy ? '生成中…' : '生成排期并写入本机'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _MonthCalendar(
              month: _calendarMonth,
              plannedIso: _plannedIso,
              onPrev: () => setState(() {
                _calendarMonth = DateTime(
                  _calendarMonth.year,
                  _calendarMonth.month - 1,
                  1,
                );
              }),
              onNext: () => setState(() {
                _calendarMonth = DateTime(
                  _calendarMonth.year,
                  _calendarMonth.month + 1,
                  1,
                );
              }),
            ),
            const SizedBox(height: 8),
            const Text(
              '圆点为按当前间隔预览的注射日（生成前仅为预览）。',
              style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: IbdColors.danger)),
              ),
            const SizedBox(height: 16),
            const Text('已生成计划',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            if (_rows.isEmpty)
              const Text('暂无数据，生成后在此列出', style: TextStyle(color: IbdColors.textSecondary)),
            ..._rows.map((row) {
              final done = row['actual_date'] != null;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    done ? Icons.check_circle_rounded : Icons.vaccines_rounded,
                    color: done ? IbdColors.success : IbdColors.primary,
                  ),
                  title: Text('${row['drug']}'),
                  subtitle: Text(
                    '计划 ${row['planned_date']}'
                    '${done ? ' · 实际 ${row['actual_date']}' : ''}'
                    ' · ${row['notes'] ?? ''}',
                  ),
                  trailing: done
                      ? null
                      : TextButton(
                          onPressed: _busy ? null : () => _complete(row),
                          child: const Text('今天已打'),
                        ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

const _label = TextStyle(
  fontWeight: FontWeight.w600,
  fontSize: 13,
  color: IbdColors.textPrimary,
);

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.plannedIso,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final Set<String> plannedIso;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final startWeekday = first.weekday % 7; // 日=0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();
    final cells = <Widget>[];

    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      final iso = isoDate(date);
      final marked = plannedIso.contains(iso);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      cells.add(
        Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: marked ? IbdColors.primary.withValues(alpha: 0.12) : null,
            border: Border.all(
              color: isToday ? IbdColors.primary : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$d',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: marked || isToday ? FontWeight.w800 : FontWeight.w500,
                  color: marked ? IbdColors.primaryDark : IbdColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: marked ? IbdColors.primary : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IbdColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
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
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
            childAspectRatio: 0.95,
            children: cells,
          ),
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
