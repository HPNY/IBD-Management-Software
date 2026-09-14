import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';

class LabManualPage extends StatefulWidget {
  const LabManualPage({super.key});

  @override
  State<LabManualPage> createState() => _LabManualPageState();
}

class _Row {
  _Row({this.name = '', this.value = '', this.unit = ''});
  String name;
  String value;
  String unit;
}

class _LabManualPageState extends State<LabManualPage> {
  final _repo = LabRepository();
  final _dateCtrl = TextEditingController(text: _today());
  final _hospitalCtrl = TextEditingController();
  final List<_Row> _rows = [_Row()];
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
      setState(() => _error = '请至少填写一项');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    try {
      final id = await _repo.insert(
        date: _dateCtrl.text.trim(),
        hospital: _hospitalCtrl.text.trim().isEmpty
            ? null
            : _hospitalCtrl.text.trim(),
        source: 'manual',
        items: items,
      );
      if (!mounted) return;
      setState(() => _ok = '已保存到本机（$id）');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手动录入检验（本地）')),
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
          const SizedBox(height: 12),
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
          TextButton.icon(
            onPressed: () => setState(() => _rows.add(_Row())),
            icon: const Icon(Icons.add),
            label: const Text('添加一项'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? '保存中…' : '保存到本机'),
          ),
          if (_ok != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_ok!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}
