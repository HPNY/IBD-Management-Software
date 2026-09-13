import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/ibd_api_client.dart';

class InjectionPage extends StatefulWidget {
  const InjectionPage({super.key, required this.api});

  final IbdApiClient api;

  @override
  State<InjectionPage> createState() => _InjectionPageState();
}

class _InjectionPageState extends State<InjectionPage> {
  bool _busy = false;
  String? _error;
  List<dynamic> _due = [];
  List<dynamic> _injections = [];
  List<dynamic> _protocols = [];
  String? _selectedProtocol;
  final _startCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _startCtrl.text =
        '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
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
      await widget.api.ensureInjectionReminderRule();
      final due = await widget.api.listDueReminders();
      final list = await widget.api.listInjections();
      final protocols = await widget.api.listProtocols();
      if (!mounted) return;
      setState(() {
        _due = due;
        _injections = list;
        _protocols = protocols;
        if (_selectedProtocol == null && protocols.isNotEmpty) {
          _selectedProtocol =
              (protocols.first as Map)['drugKey'] as String?;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() async {
    final key = _selectedProtocol;
    if (key == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.api.generateSchedule(
        drugKey: key,
        startDate: _startCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已生成 ${r['count']} 针：${r['drug']}')),
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete(Map inj) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.api.completeInjection(inj['id'] as String);
      if (!mounted) return;
      final shifted = r['shifted'];
      final delay = r['delayDays'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delay == 0
                ? '已记录今天注射'
                : '延迟 $delay 天，已顺延 $shifted 针',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _phaseLabel(String? phase) =>
      phase == 'induction' ? '诱导期' : phase == 'maintenance' ? '维持期' : '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('注射排期'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_due.isNotEmpty) ...[
              Text('到期提醒', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._due.map((d) {
                final m = Map<String, dynamic>.from(d as Map);
                return Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active),
                    title: Text('${m['message']}'),
                    subtitle: Text(
                      '计划 ${m['plannedDate']} · ${_phaseLabel(m['phase'] as String?)}',
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            Text('生成排期', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedProtocol,
              decoration: const InputDecoration(
                labelText: '药物协议',
                border: OutlineInputBorder(),
              ),
              items: _protocols.map((p) {
                final m = Map<String, dynamic>.from(p as Map);
                return DropdownMenuItem(
                  value: m['drugKey'] as String,
                  child: Text('${m['drugName']}'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedProtocol = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _startCtrl,
              decoration: const InputDecoration(
                labelText: '起始日期 YYYY-MM-DD',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _generate,
              child: Text(_busy ? '处理中…' : '按协议生成'),
            ),
            const SizedBox(height: 20),
            Text('全部计划', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_injections.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('暂无排期，先选择协议生成'),
              ),
            ..._injections.map((raw) {
              final inj = Map<String, dynamic>.from(raw as Map);
              final done = inj['actualDate'] != null;
              return ListTile(
                leading: Icon(
                  done ? Icons.check_circle : Icons.schedule,
                  color: done
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text(
                  '${inj['drug']} · ${inj['dose']}',
                ),
                subtitle: Text(
                  '计划 ${inj['plannedDate']}'
                  '${done ? ' · 实际 ${inj['actualDate']}' : ''}'
                  ' · W${inj['weekNumber']} ${_phaseLabel(inj['phase'] as String?)}'
                  ' · ${inj['route'] == 'sc' ? '皮下' : '静脉'}',
                ),
                trailing: done
                    ? null
                    : TextButton(
                        onPressed: _busy ? null : () => _complete(inj),
                        child: const Text('今天已打'),
                      ),
              );
            }),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
