import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/ui/theme.dart';

class SymptomPage extends StatefulWidget {
  const SymptomPage({super.key, this.embedded = false});

  /// true：作为底部导航 Tab，隐藏返回键
  final bool embedded;

  @override
  State<SymptomPage> createState() => _SymptomPageState();
}

class _SymptomPageState extends State<SymptomPage> {
  final _repo = SymptomRepository();
  double _pain = 0;
  int _diarrhea = 0;
  int _stoolType = 4;
  bool _blood = false;
  bool _nausea = false;
  bool _fatigueFlag = false;
  double _fatigue = 0;
  String _feeling = 'same';
  bool _saved = false;

  Future<void> _save() async {
    final n = DateTime.now();
    final date =
        '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    await _repo.upsert(
      date: date,
      painLevel: _pain.round(),
      diarrheaCount: _diarrhea,
      stoolType: _stoolType,
      bloodyStool: _blood ? 'obvious' : 'none',
      bloating: _fatigue.round(),
      fatigue: _fatigue.round(),
      nausea: _nausea,
      overallFeeling: _feeling,
    );
    if (mounted) setState(() => _saved = true);
  }

  Color _painColor(double v) {
    if (v <= 3) return IbdColors.success;
    if (v <= 6) return IbdColors.warning;
    return IbdColors.danger;
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
      body: ListView(
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
                    Text('无痛', style: _hintStyle),
                    Text('可忍受', style: _hintStyle),
                    Text('剧痛', style: _hintStyle),
                  ],
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
            child: SliderTheme(
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
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: 7,
                  itemBuilder: (context, i) {
                    final type = i + 1;
                    final selected = type == _stoolType;
                    final ideal = type == 4;
                    return InkWell(
                      onTap: () => setState(() {
                        _stoolType = type;
                        _saved = false;
                      }),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? IbdColors.primary
                              : (ideal
                                  ? const Color(0xFFCCFBF1)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? IbdColors.primary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _bristolEmoji(type),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$type',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? Colors.white
                                    : IbdColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '4 型为理想便型（深绿提示）',
                  style: _hintStyle.copyWith(color: IbdColors.primaryDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '其他症状',
            child: Column(
              children: [
                _SwitchRow(
                  label: '便血',
                  value: _blood,
                  thumbColor: IbdColors.danger,
                  onChanged: (v) => setState(() {
                    _blood = v;
                    _saved = false;
                  }),
                ),
                const Divider(height: 1),
                _SwitchRow(
                  label: '恶心',
                  value: _nausea,
                  onChanged: (v) => setState(() {
                    _nausea = v;
                    _saved = false;
                  }),
                ),
                const Divider(height: 1),
                _SwitchRow(
                  label: '疲劳感明显',
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
            child: Row(
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
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: Icon(_saved ? Icons.check_circle_rounded : Icons.edit_rounded),
            label: Text(_saved ? '已保存到本机' : '保存今日打卡'),
          ),
        ],
      ),
    );
  }

  static String _bristolEmoji(int t) {
    switch (t) {
      case 1:
        return '🫘';
      case 2:
        return '🌰';
      case 3:
        return '🌽';
      case 4:
        return '🌭';
      case 5:
        return '☁️';
      case 6:
        return '🌫';
      default:
        return '💧';
    }
  }
}

const _hintStyle = TextStyle(
  fontSize: 12,
  color: IbdColors.textSecondary,
);

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
    this.thumbColor,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? thumbColor;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      value: value,
      activeThumbColor: thumbColor ?? IbdColors.primary,
      onChanged: onChanged,
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
