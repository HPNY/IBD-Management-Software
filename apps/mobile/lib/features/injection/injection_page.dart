import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/injection/protocols.dart';
import '../../core/notify/local_notify.dart';

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
      final pending = await _repo.listPending();
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
          SnackBar(content: Text('已在本机生成 ${protocol.drugName} 排期')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('注射排期（本地）'),
        actions: [
          IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('生成排期', style: Theme.of(context).textTheme.titleMedium),
            DropdownButtonFormField<String>(
              value: _protocolKey,
              decoration: const InputDecoration(
                labelText: '药物协议',
                border: OutlineInputBorder(),
              ),
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
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _generate,
              child: Text(_busy ? '处理中…' : '本地生成并设提醒'),
            ),
            const SizedBox(height: 16),
            Text('全部计划', style: Theme.of(context).textTheme.titleMedium),
            if (_rows.isEmpty) const Padding(
              padding: EdgeInsets.all(12),
              child: Text('暂无排期'),
            ),
            ..._rows.map((row) {
              final done = row['actual_date'] != null;
              return ListTile(
                leading: Icon(
                  done ? Icons.check_circle : Icons.schedule,
                  color: done
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text('${row['drug']} · ${row['dose']}'),
                subtitle: Text(
                  '计划 ${row['planned_date']}'
                  '${done ? ' · 实际 ${row['actual_date']}' : ''}'
                  ' · ${row['phase']} · W${row['week_number']}',
                ),
                trailing: done
                    ? null
                    : TextButton(
                        onPressed: _busy ? null : () => _complete(row),
                        child: const Text('今天已打'),
                      ),
              );
            }),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}
