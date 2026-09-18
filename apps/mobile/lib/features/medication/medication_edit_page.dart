import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/ui/theme.dart';

/// iOS 健康 App 风格：新增/编辑用药
class MedicationEditPage extends StatefulWidget {
  const MedicationEditPage({super.key, this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<MedicationEditPage> createState() => _MedicationEditPageState();
}

class _MedicationEditPageState extends State<MedicationEditPage> {
  final _repo = MedicationRepository();
  final _nameCtrl = TextEditingController();
  final _strengthCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _startCtrl = TextEditingController();

  static const _forms = ['片剂', '胶囊', '口服液', '注射', '外用', '其他'];
  static const _freqs = [
    '每日一次',
    '每日两次',
    '每日三次',
    '隔日一次',
    '每周一次',
    '按需',
  ];
  static const _colors = [
    Color(0xFF0D9488),
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
  ];

  String _form = '片剂';
  String _freq = '每日一次';
  Color _color = _colors.first;
  bool _morning = true;
  bool _noon = false;
  bool _evening = false;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _nameCtrl.text = init?['drug_name'] as String? ?? '';
    _strengthCtrl.text = init?['dosage'] as String? ?? '';
    _noteCtrl.text = init?['reason'] as String? ?? '';
    _startCtrl.text = init?['start_date'] as String? ??
        DateTime.now().toIso8601String().substring(0, 10);
    final freq = init?['frequency'] as String?;
    if (freq != null && _freqs.contains(freq)) _freq = freq;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _strengthCtrl.dispose();
    _noteCtrl.dispose();
    _startCtrl.dispose();
    super.dispose();
  }

  String get _scheduleLabel {
    final slots = <String>[
      if (_morning) '早',
      if (_noon) '午',
      if (_evening) '晚',
    ];
    if (slots.isEmpty) return _freq;
    return '$_freq · ${slots.join('/')}';
  }

  Future<void> _pickDate() async {
    final init = DateTime.tryParse(_startCtrl.text) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2015),
      lastDate: DateTime(2035),
    );
    if (d == null) return;
    _startCtrl.text = d.toIso8601String().substring(0, 10);
    setState(() {});
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = '请填写药品名称');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = {
        'drugName': _nameCtrl.text.trim(),
        'dosage': _strengthCtrl.text.trim().isEmpty ? '—' : _strengthCtrl.text.trim(),
        'frequency': _scheduleLabel,
        'route': _form == '注射' ? 'sc' : (_form == '口服液' || _form == '片剂' || _form == '胶囊' ? 'oral' : 'oral'),
        'startDate': _startCtrl.text.trim(),
        'status': 'active',
        'reason': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      };
      if (_isEdit) {
        await _repo.stop(widget.initial!['id'] as String, reason: '编辑');
      }
      await _repo.insert(payload);
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
      appBar: AppBar(
        title: Text(_isEdit ? '编辑用药' : '添加用药'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? '…' : '保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _IosCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('药品名称'),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: '例如：美沙拉嗪',
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
                const Divider(height: 24),
                const _FieldLabel('规格 / 每次剂量'),
                TextField(
                  controller: _strengthCtrl,
                  decoration: const InputDecoration(
                    hintText: '例如：400mg',
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _IosCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('剂型'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _forms
                      .map(
                        (f) => ChoiceChip(
                          label: Text(f),
                          selected: _form == f,
                          onSelected: (_) => setState(() => _form = f),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                const _FieldLabel('频次'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _freqs
                      .map(
                        (f) => ChoiceChip(
                          label: Text(f),
                          selected: _freq == f,
                          onSelected: (_) => setState(() => _freq = f),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                const _FieldLabel('服药时间'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _SlotChip(
                      label: '早',
                      selected: _morning,
                      onTap: () => setState(() => _morning = !_morning),
                    ),
                    const SizedBox(width: 8),
                    _SlotChip(
                      label: '午',
                      selected: _noon,
                      onTap: () => setState(() => _noon = !_noon),
                    ),
                    const SizedBox(width: 8),
                    _SlotChip(
                      label: '晚',
                      selected: _evening,
                      onTap: () => setState(() => _evening = !_evening),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '当前：$_scheduleLabel',
                  style: const TextStyle(
                    fontSize: 13,
                    color: IbdColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _IosCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('标识颜色'),
                const SizedBox(height: 10),
                Row(
                  children: _colors
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => setState(() => _color = c),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _color == c
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: _color == c
                                    ? [
                                        BoxShadow(
                                          color: c.withOpacity(0.45),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: _color == c
                                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                                  : null,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _IosCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('开始日期'),
                TextField(
                  controller: _startCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: InputDecoration(
                    hintText: 'YYYY-MM-DD',
                    border: InputBorder.none,
                    filled: false,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined, size: 20),
                      onPressed: _pickDate,
                    ),
                  ),
                ),
                const Divider(height: 20),
                const _FieldLabel('备注（可选）'),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: '医生叮嘱、适应症等',
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? '保存中…' : (_isEdit ? '保存修改' : '添加到本机')),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: IbdColors.danger)),
            ),
        ],
      ),
    );
  }
}

class _IosCard extends StatelessWidget {
  const _IosCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: IbdColors.textSecondary,
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? IbdColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : IbdColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
