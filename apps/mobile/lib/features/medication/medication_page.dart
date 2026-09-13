import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/ibd_api_client.dart';
import 'medication_edit_page.dart';

class MedicationPage extends StatefulWidget {
  const MedicationPage({super.key, required this.api});

  final IbdApiClient api;

  @override
  State<MedicationPage> createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  bool _busy = false;
  String? _error;
  List<dynamic> _current = [];
  Map<String, dynamic>? _timeline;

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
      final current = await widget.api.listCurrentMedications();
      final timeline = await widget.api.medicationTimeline();
      if (!mounted) return;
      setState(() {
        _current = current;
        _timeline = timeline;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop(Map med) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('停药原因'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: '如：应答不佳 / 副作用 / 医保'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('停用')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.stopMedication(
        med['id'] as String,
        reason: reasonCtrl.text.trim(),
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  String _route(String? r) =>
      r == 'oral' ? '口服' : r == 'sc' ? '皮下' : r == 'iv' ? '静脉' : '';

  @override
  Widget build(BuildContext context) {
    final chain = _timeline?['chainText'] as String?;
    final history = (_timeline?['medications'] as List?) ?? const [];
    final adverse = (_timeline?['adverseEvents'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('用药管理'),
        actions: [
          IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy
            ? null
            : () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MedicationEditPage(api: widget.api),
                  ),
                );
                await _load();
              },
        icon: const Icon(Icons.add),
        label: const Text('新增用药'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (chain != null && chain.isNotEmpty) ...[
              Text('切换链', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(chain),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('当前方案', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_current.isEmpty) const Text('暂无在用/暂停药物'),
            ..._current.map((raw) {
              final m = Map<String, dynamic>.from(raw as Map);
              return Card(
                child: ListTile(
                  title: Text('${m['drugName']} ${m['dosage']}'),
                  subtitle: Text(
                    '${m['frequency']} · ${_route(m['route'] as String?)}'
                    '${m['status'] == 'paused' ? ' · 已暂停' : ''}'
                    '\n自 ${m['startDate']}'
                    '${m['reason'] == null ? '' : '\n${m['reason']}'}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'stop') await _stop(m);
                      if (v == 'edit') {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MedicationEditPage(
                              api: widget.api,
                              initial: m,
                            ),
                          ),
                        );
                        await _load();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'stop', child: Text('停药')),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Text('历史时间线', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...history.map((raw) {
              final m = Map<String, dynamic>.from(raw as Map);
              return ListTile(
                dense: true,
                leading: Icon(
                  m['status'] == 'stopped' ? Icons.stop_circle : Icons.medication,
                  size: 20,
                ),
                title: Text('${m['drugName']} ${m['dosage']}'),
                subtitle: Text(
                  '${m['startDate']} → ${m['endDate'] ?? '至今'}'
                  ' · ${m['status'] ?? ''}'
                  '${m['reason'] == null ? '' : '\n${m['reason']}'}',
                ),
              );
            }),
            if (adverse.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('副作用记录', style: Theme.of(context).textTheme.titleMedium),
              ...adverse.map((raw) {
                final a = Map<String, dynamic>.from(raw as Map);
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning_amber, size: 20),
                  title: Text('${a['title']}'),
                  subtitle: Text(
                    '${a['drugName'] ?? ''} · ${a['occurredAt']} · ${a['severity']}',
                  ),
                );
              }),
            ],
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
