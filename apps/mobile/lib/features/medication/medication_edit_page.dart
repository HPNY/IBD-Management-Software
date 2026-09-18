import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/backup/backup_service.dart';
import '../../core/db/repositories.dart';
import '../../core/identity/local_identity.dart';
import '../../core/ui/theme.dart';

/// 本地优先：新增/编辑用药写入 sqflite。
class MedicationEditPage extends StatefulWidget {
  const MedicationEditPage({super.key, this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<MedicationEditPage> createState() => _MedicationEditPageState();
}

class _MedicationEditPageState extends State<MedicationEditPage> {
  final _repo = MedicationRepository();
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
    _drugCtrl =
        TextEditingController(text: init?['drugName'] as String? ?? '');
    _brandCtrl =
        TextEditingController(text: init?['brandName'] as String? ?? '');
    _categoryCtrl =
        TextEditingController(text: init?['category'] as String? ?? '');
    _dosageCtrl =
        TextEditingController(text: init?['dosage'] as String? ?? '');
    _freqCtrl =
        TextEditingController(text: init?['frequency'] as String? ?? '');
    _reasonCtrl =
        TextEditingController(text: init?['reason'] as String? ?? '');
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
    if (_drugCtrl.text.trim().isEmpty) {
      setState(() => _error = '请填写药名');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var reason = _reasonCtrl.text.trim();
      final identity = context.read<LocalIdentity>();
      final pass = await BackupService(identity.uuid).loadPassphrase();
      if (pass != null && reason.isNotEmpty) {
        reason = await encryptSensitiveField(reason, pass, identity.uuid);
      }

      if (_isEdit) {
        // MVP：编辑走新增覆盖式——停旧再开新
        await _repo.stop(widget.initial!['id'] as String, reason: '编辑');
        await _repo.insert({
          'drugName': _drugCtrl.text.trim(),
          'brandName': _brandCtrl.text.trim(),
          'category': _categoryCtrl.text.trim(),
          'dosage': _dosageCtrl.text.trim(),
          'frequency': _freqCtrl.text.trim(),
          'route': _route,
          'startDate': _startCtrl.text.trim(),
          'status': 'active',
          'reason': reason,
        });
      } else {
        await _repo.insert({
          'drugName': _drugCtrl.text.trim(),
          'brandName': _brandCtrl.text.trim(),
          'category': _categoryCtrl.text.trim(),
          'dosage': _dosageCtrl.text.trim(),
          'frequency': _freqCtrl.text.trim(),
          'route': _route,
          'startDate': _startCtrl.text.trim(),
          'status': 'active',
          'reason': reason,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(title: Text(_isEdit ? '编辑用药' : '新增用药')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _drugCtrl,
            decoration: const InputDecoration(labelText: '药物通用名'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _brandCtrl,
            decoration: const InputDecoration(labelText: '商品名（可选）'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _categoryCtrl,
            decoration: const InputDecoration(labelText: '类别（如 JAK抑制剂）'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dosageCtrl,
                  decoration: const InputDecoration(labelText: '剂量'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _freqCtrl,
                  decoration: const InputDecoration(labelText: '频次'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _route,
            decoration: const InputDecoration(labelText: '给药方式'),
            items: const [
              DropdownMenuItem(value: 'oral', child: Text('口服')),
              DropdownMenuItem(value: 'sc', child: Text('皮下')),
              DropdownMenuItem(value: 'iv', child: Text('静脉')),
            ],
            onChanged: (v) => setState(() => _route = v ?? 'oral'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _startCtrl,
            decoration: const InputDecoration(labelText: '起始日期 YYYY-MM-DD'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '备注/原因（可加密保存）',
              helperText: '已设置备份口令时，将加密存入本机',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? '保存中…' : '保存到本机'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: TextStyle(color: IbdColors.danger)),
            ),
        ],
      ),
    );
  }
}
