import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';

class MedicationPage extends StatefulWidget {
  const MedicationPage({super.key});

  @override
  State<MedicationPage> createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  final _repo = MedicationRepository();
  List<Map<String, dynamic>> _current = [];
  List<Map<String, dynamic>> _all = [];
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
      final current = await _repo.listCurrent();
      final all = await _repo.listAll();
      if (mounted) {
        setState(() {
          _current = current;
          _all = all;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final drug = TextEditingController();
    final dosage = TextEditingController(text: '15mg');
    final freq = TextEditingController(text: '每日一次');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增用药（本地）'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: drug,
              decoration: const InputDecoration(labelText: '药名'),
            ),
            TextField(
              controller: dosage,
              decoration: const InputDecoration(labelText: '剂量'),
            ),
            TextField(
              controller: freq,
              decoration: const InputDecoration(labelText: '频次'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.insert({
      'drugName': drug.text.trim(),
      'dosage': dosage.text.trim(),
      'frequency': freq.text.trim(),
      'route': 'oral',
      'startDate': DateTime.now().toIso8601String().substring(0, 10),
      'status': 'active',
    });
    await _load();
  }

  Future<void> _stop(Map<String, dynamic> med) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('停药原因'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(hintText: '应答不佳 / 副作用 / 换药'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('停用')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.stop(med['id'] as String, reason: reason.text.trim());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用药管理（本地）'),
        actions: [
          IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : _add,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('当前方案', style: Theme.of(context).textTheme.titleMedium),
            if (_current.isEmpty) const Text('暂无'),
            ..._current.map((m) => Card(
                  child: ListTile(
                    title: Text('${m['drug_name']} ${m['dosage']}'),
                    subtitle: Text('${m['frequency']} · 自 ${m['start_date']}'),
                    trailing: TextButton(
                      onPressed: () => _stop(m),
                      child: const Text('停药'),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
            Text('历史', style: Theme.of(context).textTheme.titleMedium),
            ..._all.map((m) => ListTile(
                  dense: true,
                  leading: Icon(
                    m['status'] == 'stopped'
                        ? Icons.stop_circle
                        : Icons.medication,
                    size: 20,
                  ),
                  title: Text('${m['drug_name']} ${m['dosage']}'),
                  subtitle: Text(
                    '${m['start_date']} → ${m['end_date'] ?? '至今'} · ${m['status']}'
                    '${m['reason'] == null ? '' : '\n${m['reason']}'}',
                  ),
                )),
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
