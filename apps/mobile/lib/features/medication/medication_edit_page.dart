import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/ui/theme.dart';

/// iOS 健康 App 风格：新增/编辑用药（频次 ↔ 时间点联动）
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

  /// 频次 → 每日应选时间点数量；null = 自选（按需）
  static const _freqRules = <String, int?>{
    '每日一次': 1,
    '每日两次': 2,
    '每日三次': 3,
    '隔日一次': 1,
    '每周一次': 1,
    '按需': null,
  };

  static const _slotMeta = <String, (String label, String defaultTime)>{
    'morning': ('早', '08:00'),
    'noon': ('午', '12:00'),
    'evening': ('晚', '20:00'),
    'night': ('夜', '22:00'),
  };

  String _form = '片剂';
  String _freq = '每日一次';
  /// 已选时间点 key
  final Set<String> _slots = {'morning'};
  /// 自定义钟点（可覆盖默认）
  final Map<String, TimeOfDay> _times = {
    'morning': const TimeOfDay(hour: 8, minute: 0),
    'noon': const TimeOfDay(hour: 12, minute: 0),
    'evening': const TimeOfDay(hour: 20, minute: 0),
    'night': const TimeOfDay(hour: 22, minute: 0),
  };
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  int? get _requiredSlots => _freqRules[_freq];

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _nameCtrl.text = init?['drug_name'] as String? ?? '';
    _strengthCtrl.text = init?['dosage'] as String? ?? '';
    _noteCtrl.text = init?['reason'] as String? ?? '';
    _startCtrl.text = init?['start_date'] as String? ??
        DateTime.now().toIso8601String().substring(0, 10);

    final freqRaw = init?['frequency'] as String?;
    if (freqRaw != null) {
      for (final k in _freqRules.keys) {
        if (freqRaw.startsWith(k)) {
          _freq = k;
          break;
        }
      }
      // 从旧摘要里尝试解析已选槽位
      _slots.clear();
      if (freqRaw.contains('早')) _slots.add('morning');
      if (freqRaw.contains('午')) _slots.add('noon');
      if (freqRaw.contains('晚')) _slots.add('evening');
      if (freqRaw.contains('夜')) _slots.add('night');
      if (_slots.isEmpty) _applyFreqDefaults(_freq);
    } else {
      _applyFreqDefaults(_freq);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _strengthCtrl.dispose();
    _noteCtrl.dispose();
    _startCtrl.dispose();
    super.dispose();
  }

  void _applyFreqDefaults(String freq) {
    final n = _freqRules[freq];
    _slots.clear();
    if (n == null) {
      // 按需：默认不强制时间
      return;
    }
    const order = ['morning', 'noon', 'evening', 'night'];
    for (var i = 0; i < n && i < order.length; i++) {
      _slots.add(order[i]);
    }
  }

  void _onFreqChanged(String freq) {
    setState(() {
      _freq = freq;
      _applyFreqDefaults(freq);
    });
  }

  Future<void> _toggleSlot(String slot) async {
    final need = _requiredSlots;
    final has = _slots.contains(slot);
    if (need == null) {
      // 按需：任意开关
      setState(() {
        has ? _slots.remove(slot) : _slots.add(slot);
      });
      return;
    }
    if (has) {
      // 不允许低于频次要求
      if (_slots.length <= need) {
        setState(() => _error = '「$_freq」需要选择 $need 个时间点，不能取消');
        return;
      }
      setState(() {
        _slots.remove(slot);
        _error = null;
      });
    } else {
      if (_slots.length >= need) {
        // 超出：替换——先移除最早的
        setState(() {
          _slots.remove(_slots.first);
          _slots.add(slot);
          _error = '「$_freq」仅可选 $need 个时间点，已替换为新选择';
        });
        return;
      }
      setState(() {
        _slots.add(slot);
        _error = null;
      });
    }
  }

  Future<void> _pickTime(String slot) async {
    final t = await showTimePicker(
      context: context,
      initialTime: _times[slot] ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (t == null) return;
    setState(() => _times[slot] = t);
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get _scheduleLabel {
    final parts = _slots.map((s) {
      final meta = _slotMeta[s]!;
      return '${meta.$1}${_fmtTime(_times[s]!)}';
    }).toList();
    if (parts.isEmpty) return _freq;
    return '$_freq · ${parts.join(' / ')}';
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
    final need = _requiredSlots;
    if (need != null && _slots.length != need) {
      setState(() => _error = '「$_freq」请选择 $need 个服药时间点');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final route = _form == '注射'
          ? 'sc'
          : (_form == '外用' ? 'oral' : 'oral');
      if (_isEdit) {
        await _repo.stop(widget.initial!['id'] as String, reason: '编辑');
      }
      await _repo.insert({
        'drugName': _nameCtrl.text.trim(),
        'dosage':
            _strengthCtrl.text.trim().isEmpty ? '—' : _strengthCtrl.text.trim(),
        'frequency': _scheduleLabel,
        'route': route,
        'startDate': _startCtrl.text.trim(),
        'status': 'active',
        'reason': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final need = _requiredSlots;

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
                const SizedBox(height: 18),
                const _FieldLabel('频次'),
                const SizedBox(height: 4),
                const Text(
                  '选定频次后，下方时间点数量会与之对应；可点时间改钟点。',
                  style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _freqRules.keys
                      .map(
                        (f) => ChoiceChip(
                          label: Text(f),
                          selected: _freq == f,
                          onSelected: (_) => _onFreqChanged(f),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: _FieldLabel('服药时间点')),
                    Text(
                      need == null
                          ? '可选 ${_slots.length} 个'
                          : '已选 ${_slots.length} / $need',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: IbdColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._slotMeta.entries.map((e) {
                  final key = e.key;
                  final label = e.value.$1;
                  final selected = _slots.contains(key);
                  final time = _fmtTime(_times[key]!);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _toggleSlot(key),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: selected
                              ? IbdColors.primary.withOpacity(0.10)
                              : const Color(0xFFF8FAFC),
                          border: Border.all(
                            color: selected
                                ? IbdColors.primary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: selected
                                  ? IbdColors.primary
                                  : IbdColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$label  $time',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? IbdColors.primaryDark
                                      : IbdColors.textPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _pickTime(key),
                              child: const Text('改时间'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 6),
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
