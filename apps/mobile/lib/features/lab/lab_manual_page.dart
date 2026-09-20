import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/lab/lab_panels.dart';

/// 手动录入检验：先选大项，自动带出小项名称/单位/参考范围，只填数值。
class LabManualPage extends StatefulWidget {
  const LabManualPage({super.key, this.labRepo});

  final LabRepository? labRepo;

  @override
  State<LabManualPage> createState() => _LabManualPageState();
}

class _CustomRow {
  _CustomRow();
  String name = '';
  String value = '';
  String unit = '';
}

class _LabManualPageState extends State<LabManualPage> {
  late final LabRepository _repo = widget.labRepo ?? LabRepository();
  final _dateCtrl = TextEditingController(text: _today());
  final _hospitalCtrl = TextEditingController();

  final Set<String> _selectedPanels = {'ibd_core'};
  final Map<String, String> _values = {};
  final List<_CustomRow> _customRows = <_CustomRow>[];
  bool _busy = false;
  String? _error;
  String? _ok;

  static String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  List<LabItemSpec> get _specs => mergeLabItems(_selectedPanels);

  @override
  void dispose() {
    _dateCtrl.dispose();
    _hospitalCtrl.dispose();
    super.dispose();
  }

  void _togglePanel(String id) {
    setState(() {
      if (!_selectedPanels.remove(id)) _selectedPanels.add(id);
      _ok = null;
      _error = null;
    });
  }

  Future<void> _save() async {
    final items = <Map<String, dynamic>>[];

    for (final spec in _specs) {
      final raw = (_values[spec.nameNorm] ?? '').trim();
      if (raw.isEmpty) continue;
      final value = double.tryParse(raw);
      if (value == null) {
        setState(() => _error = '「${spec.nameNorm}」数值无效');
        return;
      }
      items.add({
        'nameNorm': spec.nameNorm,
        'nameRaw': spec.nameRaw ?? spec.nameNorm,
        'value': value,
        'unit': spec.unit,
        'refMin': spec.refMin,
        'refMax': spec.refMax,
        'flag': spec.flagOf(value),
      });
    }

    for (final row in _customRows) {
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
      setState(() => _error = '请先选择大项并至少填写一项数值');
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
      setState(() => _ok = '已保存 ${items.length} 项到本机（$id）');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final specs = _specs;
    final filled =
        specs.where((s) => (_values[s.nameNorm] ?? '').trim().isNotEmpty).length;

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
          const SizedBox(height: 16),
          Text(
            '检验大项',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '选中后自动带出小项名称与单位，只需填写数值',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kLabPanels.map((panel) {
              final selected = _selectedPanels.contains(panel.id);
              return FilterChip(
                label: Text(panel.title),
                selected: selected,
                onSelected: (_) => _togglePanel(panel.id),
                avatar: selected ? const Icon(Icons.check, size: 16) : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (specs.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '请至少选择一个检验大项',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            )
          else ...[
            Row(
              children: [
                Text(
                  '待填小项',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$filled / ${specs.length} 已填',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...specs.map((spec) => _PanelItemCard(
                  spec: spec,
                  value: _values[spec.nameNorm] ?? '',
                  onChanged: (v) => setState(() {
                    _values[spec.nameNorm] = v;
                    _ok = null;
                    _error = null;
                  }),
                )),
          ],
          const SizedBox(height: 12),
          Text(
            '其他项目（可选）',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ..._customRows.asMap().entries.map((e) {
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
                    onPressed: () => setState(() => _customRows.removeAt(i)),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _customRows.add(_CustomRow())),
            icon: const Icon(Icons.add),
            label: const Text('添加自定义一项'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? '保存中…' : '保存到本机'),
          ),
          if (_ok != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _ok!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PanelItemCard extends StatelessWidget {
  const _PanelItemCard({
    required this.spec,
    required this.value,
    required this.onChanged,
  });

  final LabItemSpec spec;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parsed = double.tryParse(value.trim());
    final flag = parsed == null ? null : spec.flagOf(parsed);
    final refText = spec.displayRef;

    Color? flagColor;
    String? flagText;
    if (flag == 'high') {
      flagColor = scheme.error;
      flagText = '偏高 ↑';
    } else if (flag == 'low') {
      flagColor = Colors.orange.shade800;
      flagText = '偏低 ↓';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.nameNorm,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if ((spec.nameRaw ?? '').isNotEmpty) spec.nameRaw!,
                      spec.unit,
                      if (refText.isNotEmpty) '参考 $refText',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (flagText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        flagText,
                        style: TextStyle(
                          color: flagColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: TextFormField(
                key: ValueKey('lab-${spec.nameNorm}'),
                initialValue: value,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: '数值',
                  isDense: true,
                  suffixText: spec.unit,
                  border: const OutlineInputBorder(),
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
