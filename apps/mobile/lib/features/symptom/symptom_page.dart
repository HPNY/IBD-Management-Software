import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/checkin/diary_severity.dart';
import '../../core/checkin/quick_template.dart';
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

  // G2：日记补全
  bool _oralUlcer = false;
  bool _jointPain = false;
  final Set<String> _jointSites = <String>{};
  final List<Map<String, String>> _customItems = <Map<String, String>>[];

  // G4：睡眠/压力
  double _sleepHours = 7;
  int _sleepQuality = 3;
  bool _sleepInsomnia = false;
  int _nightWakes = 0;
  int _stressLevel = 5;
  String? _stressSource;

  // G2：快捷模板 + 日历热力
  Map<String, dynamic>? _yesterday;
  final Map<String, double> _severityByDate = <String, double>{};
  String? _selectedCalDate;

  /// 睡眠/压力区是否被用户改过或本日本来有值；否则保存为 null（可选不填）。
  bool _wellnessTouched = false;

  static const _jointSiteOptions = ['膝', '踝', '手', '肘', '背', '其他'];
  static const _stressSources = ['工作', '家庭', '疾病', '其他'];

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
    final yesterdayDate = _isoDate(n.subtract(const Duration(days: 1)));
    final yesterday = await _repo.getByDate(yesterdayDate);
    final all = await _repo.listAll();
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
        // G2/G4 回读
        final ulcer = row['oral_ulcer'];
        _oralUlcer = ulcer == 1 || ulcer == true;
        final jp = row['joint_pain'];
        _jointPain = jp == 1 || jp == true;
        final site = '${row['joint_pain_site'] ?? ''}';
        _jointSites
          ..clear()
          ..addAll(
            site
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty && _jointSiteOptions.contains(s)),
          );
        _customItems
          ..clear()
          ..addAll(_decodeCustomItems(row['custom_items']));
        _sleepHours = ((row['sleep_hours'] as num?) ?? 7).toDouble();
        _sleepQuality = ((row['sleep_quality'] as num?) ?? 3).toInt();
        final ins = row['sleep_insomnia'];
        _sleepInsomnia = ins == 1 || ins == true;
        _nightWakes = ((row['night_wakes'] as num?) ?? 0).toInt();
        _stressLevel = ((row['stress_level'] as num?) ?? 5).toInt();
        final ss = '${row['stress_source'] ?? ''}';
        _stressSource = ss.isEmpty ? null : ss;
        _wellnessTouched = row['sleep_hours'] != null ||
            row['sleep_quality'] != null ||
            row['sleep_insomnia'] != null ||
            row['night_wakes'] != null ||
            row['stress_level'] != null ||
            row['stress_source'] != null;
        _saved = true;
      }
      _yesterday = yesterday;
      _severityByDate.clear();
      for (final s in all) {
        final d = '${s['date']}';
        _severityByDate[d] = diarySeverity(
          painLevel: (s['pain_level'] as num?)?.round(),
          bowelCount: (s['bowel_count'] as num?)?.round(),
          diarrheaCount: (s['diarrhea_count'] as num?)?.round(),
          bloodyStool: '${s['bloody_stool'] ?? ''}',
        );
      }
      _syncedToBathroom =
          bathRows.any((r) => '${r['source'] ?? ''}' == 'checkin');
      _todayBathSummary = bathRows.isEmpty ? null : _formatBathSummary(bathRows);
      _loading = false;
    });
  }

  static List<Map<String, String>> _decodeCustomItems(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (m) => {
              'label': '${m['label'] ?? ''}',
              'value': '${m['value'] ?? ''}',
            },
          )
          .where((m) => (m['label'] ?? '').isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
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
    final customJson = _customItems.isEmpty
        ? null
        : jsonEncode(
            _customItems
                .map((e) => {'label': e['label'], 'value': e['value']})
                .toList(),
          );
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
      oralUlcer: _oralUlcer,
      jointPain: _jointPain,
      jointPainSite: _jointPain && _jointSites.isNotEmpty
          ? _jointSites.join(',')
          : null,
      customItemsJson: customJson,
      sleepHours: _wellnessTouched ? _sleepHours : null,
      sleepQuality: _wellnessTouched ? _sleepQuality : null,
      sleepInsomnia: _wellnessTouched ? _sleepInsomnia : null,
      nightWakes: _wellnessTouched ? _nightWakes : null,
      stressLevel: _wellnessTouched ? _stressLevel : null,
      stressSource: _wellnessTouched ? _stressSource : null,
    );
    final bathRows = await _bathRepo.listByDate(date);
    if (!mounted) return;
    setState(() {
      _saved = true;
      _syncedToBathroom =
          bathRows.any((r) => '${r['source'] ?? ''}' == 'checkin');
      _todayBathSummary = bathRows.isEmpty ? null : _formatBathSummary(bathRows);
      final sev = diarySeverity(
        painLevel: _pain.round(),
        bowelCount: _bowelCount,
        diarrheaCount: _diarrhea,
        bloodyStool: _blood,
      );
      _severityByDate[date] = sev;
    });
  }

  void _applyQuickTemplate(String feeling) {
    final y = _yesterday;
    if (y == null) return;
    final m = prefilledFromYesterday(y, overallFeeling: feeling);
    setState(() {
      _pain = ((m['painLevel'] as num?) ?? 0).toDouble();
      _diarrhea = (m['diarrheaCount'] as num?)?.toInt() ?? 0;
      _stoolType = (m['stoolType'] as num?)?.toInt() ?? 4;
      _bowelCount = (m['bowelCount'] as num?)?.toInt() ?? 0;
      _blood = '${m['bloodyStool'] ?? 'none'}';
      _urgency = m['urgency'] == true;
      _mucus = m['mucus'] == true;
      _nausea = m['nausea'] == true;
      _fatigueFlag = m['fatigueFlag'] == true;
      _fatigue = (m['fatigue'] as num?)?.toDouble() ?? 0;
      _feeling = '${m['overallFeeling'] ?? feeling}';
      _oralUlcer = m['oralUlcer'] == true;
      _jointPain = m['jointPain'] == true;
      _jointSites
        ..clear()
        ..addAll(
          '${m['jointPainSite'] ?? ''}'
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty),
        );
      _customItems
        ..clear()
        ..addAll(_decodeCustomItems(m['customItemsJson']));
      final sh = m['sleepHours'] as num?;
      if (sh != null) {
        _sleepHours = sh.toDouble();
        _wellnessTouched = true;
      }
      final sq = m['sleepQuality'] as num?;
      if (sq != null) {
        _sleepQuality = sq.toInt();
        _wellnessTouched = true;
      }
      final hadIns = m['sleepInsomnia'] == true;
      if (hadIns) {
        _sleepInsomnia = true;
        _wellnessTouched = true;
      }
      final nw = (m['nightWakes'] as num?)?.toInt();
      if (nw != null) {
        _nightWakes = nw;
        if (nw > 0) _wellnessTouched = true;
      }
      final st = m['stressLevel'] as num?;
      if (st != null) {
        _stressLevel = st.toInt();
        _wellnessTouched = true;
      }
      final src = '${m['stressSource'] ?? ''}';
      _stressSource = src.isEmpty ? null : src;
      if (_stressSource != null) _wellnessTouched = true;
      _saved = false;
    });
  }

  Future<void> _addCustomItem() async {
    final labelCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加自定义关注项'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: '名称（如：皮疹）'),
            ),
            TextField(
              controller: valueCtrl,
              decoration: const InputDecoration(labelText: '情况（如：轻/无）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final label = labelCtrl.text.trim();
    if (label.isEmpty) return;
    setState(() {
      _customItems
          .add({'label': label, 'value': valueCtrl.text.trim()});
      _saved = false;
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
                if (_yesterday != null) ...[
                  _SectionCard(
                    title: '快捷模板',
                    trailing: const Text(
                      '预填昨日 · 仍需保存',
                      style: TextStyle(fontSize: 11, color: IbdColors.textSecondary),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '基于昨日记录一键预填，可再微调后保存。',
                          style: _hintStyle,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _QuickBtn(
                              label: '和昨天一样',
                              onTap: () => _applyQuickTemplate('same'),
                            ),
                            const SizedBox(width: 8),
                            _QuickBtn(
                              label: '比昨天好',
                              onTap: () => _applyQuickTemplate('better'),
                            ),
                            const SizedBox(width: 8),
                            _QuickBtn(
                              label: '比昨天差',
                              onTap: () => _applyQuickTemplate('worse'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _SectionCard(
                  title: '症状日历',
                  trailing: Text(
                    _selectedCalDate ?? '近 6 周',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: IbdColors.textSecondary,
                    ),
                  ),
                  child: Column(
                    children: [
                      _SeverityCalendar(
                        severityByDate: _severityByDate,
                        selected: _selectedCalDate,
                        onSelect: (d, sev) => setState(() {
                          _selectedCalDate = d;
                          if (sev != null) _severityByDate[d] = sev;
                        }),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          _LegendDot(color: Color(0xFFE2E8F0), label: '未记录'),
                          SizedBox(width: 12),
                          _LegendDot(color: IbdColors.success, label: '轻'),
                          SizedBox(width: 12),
                          _LegendDot(color: IbdColors.warning, label: '中'),
                          SizedBox(width: 12),
                          _LegendDot(color: IbdColors.danger, label: '重'),
                        ],
                      ),
                      if (_selectedCalDate != null) ...[
                        const SizedBox(height: 8),
                        Builder(
                          builder: (_) {
                            final d = _selectedCalDate!;
                            final sev = _severityByDate[d];
                            if (sev == null) {
                              return Text(
                                '$d：无记录（灰色）',
                                style: _hintStyle,
                              );
                            }
                            return Text(
                              '$d · 严重度 ${sev.toStringAsFixed(1)} / 10',
                              style: _hintStyle,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
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
                      const Divider(height: 1),
                      _SwitchRow(
                        label: '口腔溃疡',
                        hint: '口腔出现溃疡或破皮',
                        value: _oralUlcer,
                        onChanged: (v) => setState(() {
                          _oralUlcer = v;
                          _saved = false;
                        }),
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        label: '关节痛',
                        hint: '关节酸痛或肿胀',
                        value: _jointPain,
                        onChanged: (v) => setState(() {
                          _jointPain = v;
                          _saved = false;
                        }),
                      ),
                      if (_jointPain) ...[
                        const SizedBox(height: 4),
                        const Text('部位（可多选）', style: _hintStyle),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final site in _jointSiteOptions)
                              FilterChip(
                                label: Text(site),
                                selected: _jointSites.contains(site),
                                onSelected: (sel) => setState(() {
                                  if (sel) {
                                    _jointSites.add(site);
                                  } else {
                                    _jointSites.remove(site);
                                  }
                                  _saved = false;
                                }),
                                selectedColor:
                                    IbdColors.primary.withValues(alpha: 0.18),
                                checkmarkColor: IbdColors.primaryDark,
                                labelStyle: TextStyle(
                                  color: _jointSites.contains(site)
                                      ? IbdColors.primaryDark
                                      : IbdColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                      const Divider(height: 1),
                      if (_customItems.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            children: [
                              for (var i = 0; i < _customItems.length; i++)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(
                                    '${_customItems[i]['label']}：'
                                    '${_customItems[i]['value'] ?? ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    tooltip: '删除',
                                    onPressed: () => setState(() {
                                      _customItems.removeAt(i);
                                      _saved = false;
                                    }),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addCustomItem,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('添加自定义关注项'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '睡眠与压力',
                  trailing: Text(
                    '可选',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: IbdColors.textSecondary,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('睡眠时长 ${_sleepHours.toStringAsFixed(1)} 小时', style: _hintStyle),
                      Slider(
                        value: _sleepHours,
                        min: 0,
                        max: 12,
                        divisions: 24,
                        onChanged: (v) => setState(() {
                          _sleepHours = v;
                          _wellnessTouched = true;
                          _saved = false;
                        }),
                      ),
                      const SizedBox(height: 4),
                      const Text('睡眠质量', style: _hintStyle),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var q = 1; q <= 5; q++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _QualityChip(
                                score: q,
                                selected: _sleepQuality == q,
                                onTap: () => setState(() {
                                  _sleepQuality = q;
                                  _wellnessTouched = true;
                                  _saved = false;
                                }),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 20),
                      _SwitchRow(
                        label: '入睡困难',
                        hint: '躺下后较难睡着',
                        value: _sleepInsomnia,
                        onChanged: (v) => setState(() {
                          _sleepInsomnia = v;
                          _wellnessTouched = true;
                          _saved = false;
                        }),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '夜间醒来',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('$_nightWakes 次', style: _hintStyle),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _nightWakes > 0
                                  ? () => setState(() {
                                        _nightWakes--;
                                        _wellnessTouched = true;
                                        _saved = false;
                                      })
                                  : null,
                              icon: const Icon(Icons.remove_rounded),
                            ),
                            IconButton(
                              onPressed: _nightWakes < 10
                                  ? () => setState(() {
                                        _nightWakes++;
                                        _wellnessTouched = true;
                                        _saved = false;
                                      })
                                  : null,
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Text('压力水平 $_stressLevel / 10', style: _hintStyle),
                      Slider(
                        value: _stressLevel.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        onChanged: (v) => setState(() {
                          _stressLevel = v.round();
                          _wellnessTouched = true;
                          _saved = false;
                        }),
                      ),
                      const SizedBox(height: 4),
                      const Text('压力来源（可空）', style: _hintStyle),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final s in _stressSources)
                            ChoiceChip(
                              label: Text(s),
                              selected: _stressSource == s,
                              onSelected: (sel) => setState(() {
                                _stressSource = sel ? s : null;
                                _wellnessTouched = true;
                                _saved = false;
                              }),
                              selectedColor:
                                  IbdColors.primary.withValues(alpha: 0.18),
                              labelStyle: TextStyle(
                                color: _stressSource == s
                                    ? IbdColors.primaryDark
                                    : IbdColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
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
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
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
            color: selected ? color.withValues(alpha: 0.15) : Colors.white,
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
            color: selected ? color.withValues(alpha: 0.15) : Colors.white,
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

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: IbdColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: IbdColors.primaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  const _QualityChip({
    required this.score,
    required this.selected,
    required this.onTap,
  });

  final int score;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? IbdColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? IbdColors.primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          '$score',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : IbdColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: IbdColors.textSecondary)),
      ],
    );
  }
}

/// 近 6 周热力月历：颜色=严重度分档，灰色=无记录，今日描边。
class _SeverityCalendar extends StatelessWidget {
  const _SeverityCalendar({
    required this.severityByDate,
    required this.selected,
    required this.onSelect,
  });

  final Map<String, double> severityByDate;
  final String? selected;
  final void Function(String date, double? severity) onSelect;

  static String _iso(DateTime n) =>
      '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';

  Color _colorFor(DateTime day, bool isToday) {
    final sev = severityByDate[_iso(day)];
    if (sev == null) return const Color(0xFFE2E8F0);
    switch (severityBand(sev)) {
      case 'green':
        return IbdColors.success;
      case 'warning':
        return IbdColors.warning;
      default:
        return IbdColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayIso = _iso(today);
    // 周一开头的 6 个整周：本周一往前 5 周，共 42 格（含本周日）
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final start = thisMonday.subtract(const Duration(days: 35));
    final days = List.generate(42, (i) => start.add(Duration(days: i)));

    return Column(
      children: [
        Row(
          children: [
            for (final w in const ['一', '二', '三', '四', '五', '六', '日'])
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: IbdColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < 6; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final day = days[r * 7 + c];
                      final iso = _iso(day);
                      final isToday = iso == todayIso;
                      final isSel = iso == selected;
                      final color = _colorFor(day, isToday);
                      return InkWell(
                        onTap: () => onSelect(iso, severityByDate[iso]),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          height: 34,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isToday || isSel
                                  ? IbdColors.primaryDark
                                  : Colors.transparent,
                              width: isToday || isSel ? 1.5 : 0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isToday ? FontWeight.w800 : FontWeight.w600,
                              color: severityByDate[iso] == null
                                  ? IbdColors.textSecondary
                                  : Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
