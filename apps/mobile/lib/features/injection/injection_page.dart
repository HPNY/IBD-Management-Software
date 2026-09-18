import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/injection/protocols.dart';
import '../../core/notify/local_notify.dart';
import '../../core/ui/theme.dart';

class InjectionPage extends StatefulWidget {
  const InjectionPage({super.key});

  @override
  State<InjectionPage> createState() => _InjectionPageState();
}

class _InjectionPageState extends State<InjectionPage> {
  final _repo = InjectionRepository();
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  String? _protocolKey;
  final _startCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _startCtrl.text =
        '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    _protocolKey = kProtocols.first.drugKey;
    _load();
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await _repo.listAll();
      final pending = await _repo.listPending(withinDays: 60);
      await LocalNotifyService.instance.scheduleInjectionReminders(pending);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() async {
    final key = _protocolKey;
    if (key == null) return;
    final protocol = kProtocols.firstWhere((p) => p.drugKey == key);
    final start = DateTime.tryParse(_startCtrl.text.trim());
    if (start == null) {
      setState(() => _error = '起始日期无效');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.clearPendingForDrug(protocol.drugName);
      await _repo.insertMany(buildSchedule(protocol: protocol, start: start));
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已在本机生成 ${protocol.drugName} 排期'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete(Map<String, dynamic> row) async {
    await _repo.complete(row['id'] as String);
    await _load();
  }

  Color _phaseColor(String? phase) => phase == 'induction'
      ? const Color(0xFF6366F1)
      : IbdColors.primary;

  @override
  Widget build(BuildContext context) {
    final pending = _rows.where((r) => r['actual_date'] == null).length;
    final doneCount = _rows.length - pending;

    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(
        title: const Text('注射排期'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (_rows.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    _Stat(
                      value: '$pending',
                      label: '待注射',
                      color: Colors.white,
                    ),
                    Container(width: 1, height: 36, color: Colors.white24),
                    _Stat(
                      value: '$doneCount',
                      label: '已完成',
                      color: Colors.white70,
                    ),
                    Container(width: 1, height: 36, color: Colors.white24),
                    _Stat(
                      value: '${_rows.length}',
                      label: '总针次',
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: IbdColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '生成排期',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _protocolKey,
                    decoration: const InputDecoration(labelText: '药物协议'),
                    items: kProtocols
                        .map((p) => DropdownMenuItem(
                              value: p.drugKey,
                              child: Text(p.drugName),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _protocolKey = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _startCtrl,
                    decoration: const InputDecoration(
                      labelText: '起始日期 YYYY-MM-DD',
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _busy ? null : _generate,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(_busy ? '处理中…' : '本地生成并设提醒'),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: IbdColors.danger),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              '注射时间线',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: IbdColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '本地排期 · 系统通知提醒 · 延迟可顺延',
              style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (_rows.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: IbdColors.card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '暂无排期，先选择协议生成',
                  style: TextStyle(color: IbdColors.textSecondary),
                ),
              ),
            ..._rows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              final done = row['actual_date'] != null;
              final color = _phaseColor(row['phase'] as String?);
              final isLast = i == _rows.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: done ? IbdColors.success : color.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: done ? IbdColors.success : color,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          done ? Icons.check_rounded : Icons.vaccines_rounded,
                          size: 18,
                          color: done ? Colors.white : color,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 52,
                          color: const Color(0xFFE2E8F0),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: IbdColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${row['drug']} · ${row['dose']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  row['phase'] == 'induction'
                                      ? '诱导'
                                      : '维持',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '计划 ${row['planned_date']}'
                            '${done ? '\n实际 ${row['actual_date']}' : ''}'
                            ' · W${row['week_number']} · ${row['route'] == 'sc' ? '皮下' : '静脉'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: IbdColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          if (!done)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    _busy ? null : () => _complete(row),
                                child: const Text('今天已打'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color == Colors.white ? Colors.white70 : color,
            ),
          ),
        ],
      ),
    );
  }
}
