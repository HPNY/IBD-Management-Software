import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/ui/theme.dart';

class SymptomPage extends StatefulWidget {
  const SymptomPage({
    super.key,
    this.embedded = false,
    this.symptomRepo,
    this.bathroomRepo,
  });

  /// true：作为底部导航 Tab，隐藏返回键
  final bool embedded;

  /// 测试可注入仓库；生产默认走本机 LocalDb。
  final SymptomRepository? symptomRepo;
  final BathroomRepository? bathroomRepo;

  @override
  State<SymptomPage> createState() => _SymptomPageState();
}

class _SymptomPageState extends State<SymptomPage> {
  late final SymptomRepository _repo =
      widget.symptomRepo ?? SymptomRepository();
  late final BathroomRepository _bathRepo =
      widget.bathroomRepo ?? BathroomRepository();
  double _pain = 0;
  int _diarrhea = 0;
  int _stoolType = 4;
  int _bowelCount = 0;
  String _blood = 'none';
  bool _urgency = false;
  bool _mucus = false;
  bool _nausea = false;
  bool _fatigueFlag = false;
  double _fatigue = 0;
  String _feeling = 'same';
  bool _saved = false;
  bool _syncedToBathroom = false;
  String? _todayBathSummary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final n = DateTime.now();
    final date = _isoDate(n);
    final row = await _repo.getByDate(date);
    final bathRows = await _bathRepo.listByDate(date);
    if (!mounted) return;
    setState(() {
      if (row != null) {
        _pain = ((row['pain_level'] as num?) ?? 0).toDouble();
        _diarrhea = ((row['diarrhea_count'] as num?) ?? 0).toInt();
        _stoolType = ((row['stool_type'] as num?) ?? 4).toInt();
        _bowelCount = ((row['bowel_count'] as num?) ??
                (row['diarrhea_count'] as num?) ??
                0)
            .toInt();
        _blood = '${row['bloody_stool'] ?? 'none'}';
        if (_blood != 'none' && _blood != 'trace' && _blood != 'obvious') {
          _blood = _blood == '1' || _blood == 'true' ? 'obvious' : 'none';
        }
        _urgency = row['urgency'] == 1;
        _mucus = row['mucus'] == 1;
        final nausea = row['nausea'];
        _nausea = nausea == 1 || nausea == true;
        final fatigue = ((row['fatigue'] as num?) ?? 0).toDouble();
        _fatigueFlag = fatigue > 0;
        _fatigue = fatigue;
        _feeling = '${row['overall_feeling'] ?? 'same'}';
        _saved = true;
      }
      _syncedToBathroom =
          bathRows.any((r) => '${r['source'] ?? ''}' == 'checkin');
      _todayBathSummary = bathRows.isEmpty ? null : _formatBathSummary(bathRows);
      _loading = false;
    });
  }

  static String _isoDate(DateTime n) =>
      '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';

  String _formatBathSummary(List<Map<String, dynamic>> rows) {
    final parts = <String>[];
    for (final r in rows) {
      final src = '${r['source'] ?? 'manual'}' == 'checkin' ? '打卡' : '细表';
      final blood = _bloodLabelFromFlag(r['blood']);
      final flags = <String>[
        'Bristol ${r['stool_type'] ?? '—'}',
        if (r['daily_count'] != null) '累计 ${r['daily_count']} 次',
        if (r['urgency'] == 1) '紧迫',
        if (blood != null) blood,
        if (r['mucus'] == 1) '黏液',
      ];
      parts.add('${r['date']} ${r['time'] ?? ''} · $src · ${flags.join(' · ')}');
    }
    return parts.join('\n');
  }

  static String? _bloodLabelFromFlag(Object? flag) {
    switch (flag) {
      case 1:
        return '擦拭有血';
      case 2:
        return '明显便血';
      case 0:
        return null;
      default:
        return null;
    }
  }

  Future<void> _save() async {
    final date = _isoDate(DateTime.now());
    await _repo.upsert(
      date: date,
      painLevel: _pain.round(),
      diarrheaCount: _diarrhea,
      stoolType: _stoolType,
      bloodyStool: _blood,
      bloating: _fatigue.round(),
      fatigue: _fatigue.round(),
      nausea: _nausea,
      overallFeeling: _feeling,
      urgency: _urgency,
      mucus: _mucus,
      bowelCount: _bowelCount,
    );
    final bathRows = await _bathRepo.listByDate(date);
    if (!mounted) return;
    setState(() {
      _saved = true;
      _syncedToBathroom =
          bathRows.any((r) => '${r['source'] ?? ''}' == 'checkin');
      _todayBathSummary = bathRows.isEmpty ? null : _formatBathSummary(bathRows);
    });
  }

  Color _painColor(double v) {
    if (v <= 3) return IbdColors.success;
    if (v <= 6) return IbdColors.warning;
    return IbdColors.danger;
  }

  String _painHint(double v) {
    if (v <= 1) return '几乎没有腹痛';
    if (v <= 3) return '轻微，可正常活动';
    if (v <= 6) return '中等，有点难受但能忍';
    if (v <= 8) return '较重，影响活动或食欲';
    return '剧烈，建议尽快就医评估';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('今日打卡'),
        actions: [
          if (_saved)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '已保存',
                  style: TextStyle(
                    color: IbdColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _SectionCard(
                  title: '腹痛',
                  trailing: Text(
                    '${_pain.round()} / 10',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: _painColor(_pain),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _painHint(_pain),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: IbdColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _painColor(_pain),
                          thumbColor: _painColor(_pain),
                          inactiveTrackColor: const Color(0xFFE2E8F0),
                          trackHeight: 6,
                          thumbShape:
                              const RoundSliderThumbShape(enabledThumbRadius: 10),
                        ),
                        child: Slider(
                          value: _pain,
                          max: 10,
                          divisions: 10,
                          onChanged: (v) => setState(() {
                            _pain = v;
                            _saved = false;
                          }),
                        ),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0 不痛', style: _hintStyle),
                          Text('5 中等', style: _hintStyle),
                          Text('10 最痛', style: _hintStyle),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '排便次数',
                  trailing: Text(
                    '$_bowelCount 次',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: IbdColors.primary,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '今天一共排便几次？（含成形便与稀便）',
                        style: _hintStyle,
                      ),
                      const SizedBox(height: 6),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: IbdColors.primary,
                          thumbColor: IbdColors.primary,
                          inactiveTrackColor: const Color(0xFFE2E8F0),
                          trackHeight: 6,
                        ),
                        child: Slider(
                          value: _bowelCount.toDouble(),
                          max: 20,
                          divisions: 20,
                          onChanged: (v) => setState(() {
                            _bowelCount = v.round();
                            _saved = false;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '腹泻次数',
                  trailing: Text(
                    '$_diarrhea 次',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: IbdColors.primary,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '其中稀便/水样便有几次？',
                        style: _hintStyle,
                      ),
                      const SizedBox(height: 6),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: IbdColors.primary,
                          thumbColor: IbdColors.primary,
                          inactiveTrackColor: const Color(0xFFE2E8F0),
                          trackHeight: 6,
                        ),
                        child: Slider(
                          value: _diarrhea.toDouble(),
                          max: 15,
                          divisions: 15,
                          onChanged: (v) => setState(() {
                            _diarrhea = v.round();
                            _saved = false;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Bristol 粪便量表',
                  trailing: Text(
                    '$_stoolType 型',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: IbdColors.primary,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '选最像今天大便外观的一项。4 型为较理想状态。',
                        style: TextStyle(
                            fontSize: 12.5, color: IbdColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      ..._bristolOptions.map((o) {
                        final selected = o.type == _stoolType;
                        final ideal = o.type == 4;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => setState(() {
                              _stoolType = o.type;
                              _saved = false;
                            }),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? IbdColors.primary
                                    : (ideal
                                        ? const Color(0xFFCCFBF1)
                                        : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? IbdColors.primary
                                      : const Color(0xFFE2E8F0),
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${o.type}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: selected
                                          ? Colors.white
                                          : IbdColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      o.label,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.3,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: selected
                                            ? Colors.white
                                            : IbdColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (ideal && !selected)
                                    const Text(
                                      '理想',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: IbdColors.primaryDark,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '排便细项',
                  trailing: Text(
                    _syncedToBathroom ? '已同步细表' : '保存后同步细表',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _syncedToBathroom
                          ? IbdColors.success
                          : IbdColors.textSecondary,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '便血',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '与排便细表同一套分级，打卡保存后自动写入细表历史。',
                        style: _hintStyle,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _BloodChip(
                            label: '无',
                            selected: _blood == 'none',
                            color: IbdColors.success,
                            onTap: () => setState(() {
                              _blood = 'none';
                              _saved = false;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _BloodChip(
                            label: '擦拭有',
                            selected: _blood == 'trace',
                            color: IbdColors.warning,
                            onTap: () => setState(() {
                              _blood = 'trace';
                              _saved = false;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _BloodChip(
                            label: '明显',
                            selected: _blood == 'obvious',
                            color: IbdColors.danger,
                            onTap: () => setState(() {
                              _blood = 'obvious';
                              _saved = false;
                            }),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      _SwitchRow(
                        label: '紧迫感',
                        hint: '突然想排便、很难忍住',
                        value: _urgency,
                        onChanged: (v) => setState(() {
                          _urgency = v;
                          _saved = false;
                        }),
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        label: '黏液',
                        hint: '大便带黏液或鼻涕状分泌物',
                        value: _mucus,
                        onChanged: (v) => setState(() {
                          _mucus = v;
                          _saved = false;
                        }),
                      ),
                      if (_todayBathSummary != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCCFBF1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '今日排便细表记录',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: IbdColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _todayBathSummary!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: IbdColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '其他症状',
                  child: Column(
                    children: [
                      _SwitchRow(
                        label: '恶心',
                        hint: '想吐或胃里翻腾',
                        value: _nausea,
                        onChanged: (v) => setState(() {
                          _nausea = v;
                          _saved = false;
                        }),
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        label: '疲劳感明显',
                        hint: '比平时更没劲、容易累',
                        value: _fatigueFlag,
                        onChanged: (v) => setState(() {
                          _fatigueFlag = v;
                          _saved = false;
                        }),
                      ),
                      if (_fatigueFlag) ...[
                        const SizedBox(height: 8),
                        Text('疲劳 ${_fatigue.round()} / 10', style: _hintStyle),
                        Slider(
                          value: _fatigue,
                          max: 10,
                          divisions: 10,
                          onChanged: (v) => setState(() {
                            _fatigue = v;
                            _saved = false;
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '整体感受',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '和昨天比，今天整体怎么样？选一个最接近的。',
                        style: _hintStyle,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _FeelingChip(
                            label: '比昨天差',
                            selected: _feeling == 'worse',
                            color: IbdColors.danger,
                            onTap: () => setState(() {
                              _feeling = 'worse';
                              _saved = false;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _FeelingChip(
                            label: '差不多',
                            selected: _feeling == 'same',
                            color: IbdColors.warning,
                            onTap: () => setState(() {
                              _feeling = 'same';
                              _saved = false;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _FeelingChip(
                            label: '比昨天好',
                            selected: _feeling == 'better',
                            color: IbdColors.success,
                            onTap: () => setState(() {
                              _feeling = 'better';
                              _saved = false;
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_saved && _syncedToBathroom)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      '排便细项已同步到「分析 · 排便细表」，无需再填一遍。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: IbdColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _save,
                  icon: Icon(
                      _saved ? Icons.check_circle_rounded : Icons.edit_rounded),
                  label: Text(_saved ? '已保存到本机' : '保存今日打卡'),
                ),
              ],
            ),
    );
  }
}

const _hintStyle = TextStyle(
  fontSize: 12,
  color: IbdColors.textSecondary,
);

class _BristolOption {
  const _BristolOption(this.type, this.label);
  final int type;
  final String label;
}

const _bristolOptions = <_BristolOption>[
  _BristolOption(1, '分离的硬球，像坚果，很难排出'),
  _BristolOption(2, '香肠状但表面凹凸、有硬块'),
  _BristolOption(3, '香肠状，表面有裂纹'),
  _BristolOption(4, '香肠状或蛇状，光滑柔软（较理想）'),
  _BristolOption(5, '软团状，边缘清楚，容易排出'),
  _BristolOption(6, '糊状或水样，边缘糊化'),
  _BristolOption(7, '完全水样，无固体'),
];

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: IbdColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: IbdColors.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    // Section 卡片是 DecoratedBox，ListTile 需要自己的 Material 才能画水波纹
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: hint == null
            ? null
            : Text(hint!, style: const TextStyle(fontSize: 12)),
        value: value,
        activeThumbColor: IbdColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}

class _BloodChip extends StatelessWidget {
  const _BloodChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? color : IbdColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeelingChip extends StatelessWidget {
  const _FeelingChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? color : IbdColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
