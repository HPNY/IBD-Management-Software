import 'package:flutter/material.dart';

import '../../core/api/ibd_api_client.dart';

class MedicationEditPage extends StatefulWidget {
  const MedicationEditPage({super.key, required this.api, this.initial});

  final IbdApiClient api;
  final Map<String, dynamic>? initial;

  @override
  State<MedicationEditPage> createState() => _MedicationEditPageState();
}

class _MedicationEditPageState extends State<MedicationEditPage> {
  late final TextEditingController _drugCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _dosageCtrl;
  late final TextEditingController _freqCtrl;
  late final TextEditingController _reasonCtrl;
  late final TextEditingController _startCtrl;
  late String _route;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _drugCtrl = TextEditingController(text: init?['drugName'] as String? ?? '');
    _brandCtrl = TextEditingController(text: init?['brandName'] as String? ?? '');
    _categoryCtrl = TextEditingController(text: init?['category'] as String? ?? '');
    _dosageCtrl = TextEditingController(text: init?['dosage'] as String? ?? '');
    _freqCtrl = TextEditingController(text: init?['frequency'] as String? ?? '');
    _reasonCtrl = TextEditingController(text: init?['reason'] as String? ?? '');
    _startCtrl = TextEditingController(
      text: (init?['startDate'] as String?) ??
          DateTime.now().toIso8601String().substring(0, 10),
    );
    _route = (init?['route'] as String?) ?? 'oral';
  }

  @override
  void dispose() {
    _drugCtrl.dispose();
    _brandCtrl.dispose();
    _categoryCtrl.dispose();
    _dosageCtrl.dispose();
    _freqCtrl.dispose();
    _reasonCtrl.dispose();
    _startCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await widget.api.updateMedication(
          widget.initial!['id'] as String,
          {
            'drugName': _drugCtrl.text.trim(),
            'brandName': _brandCtrl.text.trim(),
            'category': _categoryCtrl.text.trim(),
            'dosage': _dosageCtrl.text.trim(),
            'frequency': _freqCtrl.text.trim(),
            'route': _route,
            'reason': _reasonCtrl.text.trim(),
          },
        );
      } else {
        await widget.api.createMedication({
          'drugName': _drugCtrl.text.trim(),
          'brandName': _brandCtrl.text.trim(),
          'category': _categoryCtrl.text.trim(),
          'dosage': _dosageCtrl.text.trim(),
          'frequency': _freqCtrl.text.trim(),
          'route': _route,
          'startDate': _startCtrl.text.trim(),
          'reason': _reasonCtrl.text.trim(),
          'status': 'active',
        });
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑用药' : '新增用药')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _drugCtrl,
            decoration: const InputDecoration(
              labelText: '药物通用名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _brandCtrl,
            decoration: const InputDecoration(
              labelText: '商品名（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _categoryCtrl,
            decoration: const InputDecoration(
              labelText: '类别（如 JAK抑制剂）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dosageCtrl,
                  decoration: const InputDecoration(
                    labelText: '剂量',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _freqCtrl,
                  decoration: const InputDecoration(
                    labelText: '频次',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _route,
            decoration: const InputDecoration(
              labelText: '给药方式',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'oral', child: Text('口服')),
              DropdownMenuItem(value: 'sc', child: Text('皮下')),
              DropdownMenuItem(value: 'iv', child: Text('静脉')),
            ],
            onChanged: (v) => setState(() => _route = v ?? 'oral'),
          ),
          const SizedBox(height: 12),
          if (!_isEdit)
            TextField(
              controller: _startCtrl,
              decoration: const InputDecoration(
                labelText: '起始日期 YYYY-MM-DD',
                border: OutlineInputBorder(),
              ),
            ),
          if (!_isEdit) const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '备注/原因',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? '保存中…' : '保存'),
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
