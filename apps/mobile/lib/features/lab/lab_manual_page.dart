import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/ibd_api_client.dart';

class LabManualPage extends StatefulWidget {
  const LabManualPage({super.key, required this.api});

  final IbdApiClient api;

  @override
  State<LabManualPage> createState() => _LabManualPageState();
}

class _LabManualEntry {
  _LabManualEntry({this.name = '', this.value = '', this.unit = ''});

  String name;
  String value;
  String unit;
}

class _LabManualPageState extends State<LabManualPage> {
  final _dateCtrl = TextEditingController(text: _today());
  final _hospitalCtrl = TextEditingController();
  final List<_LabManualEntry> _rows = [_LabManualEntry()];
  bool _busy = false;
  String? _error;
  String? _ok;

  static String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _hospitalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final items = <Map<String, dynamic>>[];
    for (final row in _rows) {
      final name = row.name.trim();
      final raw = row.value.trim();
      if (name.isEmpty || raw.isEmpty) continue;
      final value = double.tryParse(raw);
      if (value == null) {
        setState(() => _error = '「$name」数值无效');
        return;
      }
      items.add({
        'nameNorm': name,
        'nameRaw': name,
        'value': value,
        if (row.unit.trim().isNotEmpty) 'unit': row.unit.trim(),
      });
    }
    if (items.isEmpty) {
      setState(() => _error = '请至少填写一项检验结果');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    try {
      final lab = await widget.api.createLab(
        date: _dateCtrl.text.trim(),
        hospital: _hospitalCtrl.text.trim(),
        items: items,
        source: 'manual',
      );
      if (!mounted) return;
      setState(() => _ok = '已保存 ${lab['id']}（${items.length} 项）');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手动录入检验')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _dateCtrl,
            decoration: const InputDecoration(
              labelText: '检验日期 YYYY-MM-DD',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hospitalCtrl,
            decoration: const InputDecoration(
              labelText: '医院（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('检验项目', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._rows.asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: row.name,
                      decoration: const InputDecoration(
                        labelText: '项目名',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => row.name = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: row.value,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '数值',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => row.value = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: row.unit,
                      decoration: const InputDecoration(
                        labelText: '单位',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => row.unit = v,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _rows.length == 1
                        ? null
                        : () => setState(() => _rows.removeAt(i)),
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _rows.add(_LabManualEntry())),
              icon: const Icon(Icons.add),
              label: const Text('添加一项'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? '保存中…' : '保存'),
          ),
          if (_ok != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_ok!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
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
    );
  }
}
