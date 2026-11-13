import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/checkin/diary_severity.dart';
import '../../core/checkin/quick_template.dart';
import '../../core/db/local_db.dart';
import '../../core/db/repositories.dart';
import '../../core/ui/cards.dart';
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

class _SymptomPageState extends State<SymptomPage> with WidgetsBindingObserver {
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
  // T1：腹胀独立字段（不再复用疲劳值）
  bool _bloatingFlag = false;
  double _bloating = 0;

  /// 历史缺陷修复提示（data_flags bit0）：该日腹胀曾被误存为疲劳值并已置空。
  bool _bloatResetNotice = false;
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

  // U4：草稿。未保存的编辑节流写入 SharedPreferences（≤1 次/800ms），
  // 应用退到后台时补写一次；下次进入当日打卡时恢复，保存成功后清除。
  // 草稿只存本机，不上传；取不到存储时静默降级。
  static const _draftKey = 'ibd_checkin_draft_v1';
  DateTime? _lastDraftWrite;
  DateTime? _draftSavedAt;
  bool _draftRestored = false;

  static const _jointSiteOptions = ['膝', '踝', '手', '肘', '背', '其他'];
  static const _stressSources = ['工作', '家庭', '疾病', '其他'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        final bloating = ((row['bloating'] as num?) ?? 0).toDouble();
        _bloatingFlag = bloating > 0;
        _bloating = bloating;
        _bloatResetNotice =
            (((row['data_flags'] as num?) ?? 0).toInt() &
                kDataFlagBloatingReset) !=
            0;
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
    // 草稿异步套用，不阻塞首屏：存储不可用时（如测试环境无插件实现）
    // 只是没有草稿，绝不会把页面卡在 loading。
    unawaited(_restoreDraft());
  }

  Future<void> _restoreDraft() async {
    final draft = await _readDraft();
    if (draft == null || !mounted) return;
    setState(() {
      _applyDraft(draft);
      _draftRestored = true;
    });
  }

  /// 标记"有未保存改动"，并按 800ms 节流落盘草稿。
  /// 不用 Timer：避免 widget 测试里留下 pending timer，也避免 dispose 竞态。
  void _markDirty() {
    _saved = false;
    final now = DateTime.now();
    final last = _lastDraftWrite;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastDraftWrite = now;
    unawaited(_persistDraft());
  }

  Map<String, dynamic> _draftPayload() => {
        'date': _isoDate(DateTime.now()),
        'pain': _pain,
        'diarrhea': _diarrhea,
        'stoolType': _stoolType,
        'bowelCount': _bowelCount,
        'blood': _blood,
        'urgency': _urgency,
        'mucus': _mucus,
        'nausea': _nausea,
        'fatigueFlag': _fatigueFlag,
        'fatigue': _fatigue,
        'bloatingFlag': _bloatingFlag,
        'bloating': _bloating,
        'feeling': _feeling,
        'oralUlcer': _oralUlcer,
        'jointPain': _jointPain,
        'jointSites': _jointSites.toList(),
        'customItems': _customItems,
        'sleepHours': _sleepHours,
        'sleepQuality': _sleepQuality,
        'sleepInsomnia': _sleepInsomnia,
        'nightWakes': _nightWakes,
        'stressLevel': _stressLevel,
        'stressSource': _stressSource,
        'wellnessTouched': _wellnessTouched,
      };

  /// 草稿是"锦上添花"，取不到存储就降级为不启用，绝不让打卡主流程失败
  /// （无插件实现的测试环境会抛 MissingPluginException）。
  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistDraft() async {
    final payload = _draftPayload();
    final sp = await _prefs();
    if (sp == null) return;
    try {
      await sp.setString(_draftKey, jsonEncode(payload));
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _draftSavedAt = DateTime.now());
  }

  /// 读取草稿。跨日草稿视为过期并丢弃，避免昨天的值被填进今天。
  Future<Map<String, dynamic>?> _readDraft() async {
    final sp = await _prefs();
    if (sp == null) return null;
    final raw = sp.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final draft = Map<String, dynamic>.from(decoded);
      if ('${draft['date']}' != _isoDate(DateTime.now())) {
        await sp.remove(_draftKey);
        return null;
      }
      return draft;
    } catch (_) {
      await sp.remove(_draftKey);
      return null;
    }
  }

  /// 把草稿值写回表单状态。草稿存在即代表"有未保存改动"，故置 _saved=false。
  void _applyDraft(Map<String, dynamic> d) {
    double numOf(Object? v, double fallback) =>
        v is num ? v.toDouble() : fallback;
    int intOf(Object? v, int fallback) => v is num ? v.toInt() : fallback;

    _pain = numOf(d['pain'], _pain);
    _diarrhea = intOf(d['diarrhea'], _diarrhea);
    _stoolType = intOf(d['stoolType'], _stoolType);
    _bowelCount = intOf(d['bowelCount'], _bowelCount);
    final blood = '${d['blood'] ?? ''}';
    if (blood == 'none' || blood == 'trace' || blood == 'obvious') {
      _blood = blood;
    }
    _urgency = d['urgency'] == true;
    _mucus = d['mucus'] == true;
    _nausea = d['nausea'] == true;
    _fatigueFlag = d['fatigueFlag'] == true;
    _fatigue = numOf(d['fatigue'], _fatigue);
    _bloatingFlag = d['bloatingFlag'] == true;
    _bloating = numOf(d['bloating'], _bloating);
    final feeling = '${d['feeling'] ?? ''}';
    if (feeling == 'same' || feeling == 'better' || feeling == 'worse') {
      _feeling = feeling;
    }
    _oralUlcer = d['oralUlcer'] == true;
    _jointPain = d['jointPain'] == true;
    final sites = d['jointSites'];
    if (sites is List) {
      _jointSites
        ..clear()
        ..addAll(
          sites
              .map((s) => '$s')
              .where((s) => _jointSiteOptions.contains(s)),
        );
    }
    final items = d['customItems'];
    if (items is List) {
      _customItems
        ..clear()
        ..addAll(_decodeCustomItems(jsonEncode(items)));
    }
    _sleepHours = numOf(d['sleepHours'], _sleepHours);
    _sleepQuality = intOf(d['sleepQuality'], _sleepQuality);
    _sleepInsomnia = d['sleepInsomnia'] == true;
    _nightWakes = intOf(d['nightWakes'], _nightWakes);
    _stressLevel = intOf(d['stressLevel'], _stressLevel);
    final src = '${d['stressSource'] ?? ''}';
    _stressSource = src.isEmpty ? null : src;
    _wellnessTouched = d['wellnessTouched'] == true;
    _saved = false;
  }

  Future<void> _clearDraft() async {
    final sp = await _prefs();
    if (sp != null) {
      try {
        await sp.remove(_draftKey);
      } catch (_) {
        // 清不掉不影响已落库的数据，下次进入会因日期/覆盖而失效
      }
    }
    if (!mounted) return;
    setState(() {
      _draftSavedAt = null;
      _draftRestored = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 退到后台/被系统回收前补写一次草稿，覆盖节流窗口内的最后一次编辑。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistDraft());
    }
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
      // T1.1（裁决 B）：仅实际录入腹胀才写非空值（非空值会解除修复标记）；
      // 开关关闭时写 null，避免误清标记，也避免残留滑块旧值。
      bloating: _bloatingFlag ? _bloating.round() : null,
      // T1.2：疲劳同构修复——开关关闭时不写滑块旧值，写 null（未记录）。
      fatigue: _fatigueFlag ? _fatigue.round() : null,
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
    // 已落库，草稿使命结束（不阻塞保存反馈）
    unawaited(_clearDraft());
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
      _bloatingFlag = m['bloatingFlag'] == true;
      _bloating = (m['bloating'] as num?)?.toDouble() ?? 0;
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
      _markDirty();
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
      _markDirty();
    });
  }

  /// 提示文字样式：随明暗切换，故不能是文件级 const。
  TextStyle get _hintStyle => TextStyle(
        fontSize: 12,
        color: context.ibd.textSecondary,
      );

  Color _painColor(double v) {
    if (v <= 3) return context.ibd.success;
    if (v <= 6) return context.ibd.warning;
    return context.ibd.danger;
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
      backgroundColor: context.ibd.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('今日打卡'),
        actions: [
          if (_saved)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '已保存',
                  style: TextStyle(
                    color: context.ibd.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
      // U4：保存按钮常驻底部（拇指区），不再随 11 张卡片滚到第 4 屏
      bottomNavigationBar: _loading
          ? null
          : _CheckinSaveBar(
              saved: _saved,
              draftRestored: _draftRestored,
              draftSavedAt: _draftSavedAt,
              onSave: _save,
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                if (_bloatResetNotice) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.ibd.warning),
                    ),
                    child: Text(
                      '数据修复提示：本日腹胀曾因历史缺陷被误存为疲劳值，'
                      '已置空并标记；疲劳值不受影响。补录腹胀并保存后本提示消失。',
                      style: _hintStyle,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_yesterday != null) ...[
                  _SectionCard(
                    title: '快捷模板',
                    trailing: Text(
                      '预填昨日 · 仍需保存',
                      style: TextStyle(fontSize: 11, color: context.ibd.textSecondary),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.ibd.textSecondary,
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
                        children: [
                          // 图例带数值区间：格子里的数字 + 这里的区间，
                          // 灰度/色盲下不用颜色也能推出档位（「5」→「4–6 中」）
                          _LegendDot(color: context.ibd.divider, label: '未记录'),
                          const SizedBox(width: 10),
                          _LegendDot(color: context.ibd.success, label: '1–3 轻'),
                          const SizedBox(width: 10),
                          _LegendDot(color: context.ibd.warning, label: '4–6 中'),
                          const SizedBox(width: 10),
                          _LegendDot(color: context.ibd.danger, label: '7–10 重'),
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
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.ibd.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _painColor(_pain),
                          thumbColor: _painColor(_pain),
                          inactiveTrackColor: context.ibd.divider,
                          trackHeight: 6,
                          thumbShape:
                              const RoundSliderThumbShape(enabledThumbRadius: 10),
                        ),
                        child: Semantics(
                          // container: false → 标签并入 Slider 自己的语义节点：
                          // TalkBack 一次读完「腹痛程度 5 分」，且保留加减手势
                          container: false,
                          label: '腹痛程度',
                          child: Slider(
                            value: _pain,
                            max: 10,
                            divisions: 10,
                            semanticFormatterCallback: (v) => '${v.round()} 分',
                            onChanged: (v) => setState(() {
                              _pain = v;
                              _markDirty();
                            }),
                          ),
                        ),
                      ),
                      Row(
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
                      Text(
                        '今天一共排便几次？（含成形便与稀便）',
                        style: _hintStyle,
                      ),
                      const SizedBox(height: 6),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: IbdColors.primary,
                          thumbColor: IbdColors.primary,
                          inactiveTrackColor: context.ibd.divider,
                          trackHeight: 6,
                        ),
                        child: Semantics(
                          container: false,
                          label: '今天排便次数',
                          child: Slider(
                            value: _bowelCount.toDouble(),
                            max: 20,
                            divisions: 20,
                            semanticFormatterCallback: (v) => '${v.round()} 次',
                            onChanged: (v) => setState(() {
                              _bowelCount = v.round();
                              _markDirty();
                            }),
                          ),
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
                      Text(
                        '其中稀便/水样便有几次？',
                        style: _hintStyle,
                      ),
                      const SizedBox(height: 6),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: IbdColors.primary,
                          thumbColor: IbdColors.primary,
                          inactiveTrackColor: context.ibd.divider,
                          trackHeight: 6,
                        ),
                        child: Semantics(
                          container: false,
                          label: '稀便次数',
                          child: Slider(
                            value: _diarrhea.toDouble(),
                            max: 15,
                            divisions: 15,
                            semanticFormatterCallback: (v) => '${v.round()} 次',
                            onChanged: (v) => setState(() {
                              _diarrhea = v.round();
                              _markDirty();
                            }),
                          ),
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
                      Text(
                        '选最像今天大便外观的一项。4 型为较理想状态。',
                        style: TextStyle(
                            fontSize: 12.5, color: context.ibd.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      ..._bristolOptions.map((o) {
                        final selected = o.type == _stoolType;
                        final ideal = o.type == 4;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Semantics(
                            button: true,
                            selected: selected,
                            label: '${o.type} 型，${o.label}'
                                '${ideal ? '，理想型' : ''}',
                            onTap: () => setState(() {
                              _stoolType = o.type;
                              _markDirty();
                            }),
                            excludeSemantics: true,
                            child: InkWell(
                            onTap: () => setState(() {
                              _stoolType = o.type;
                              _markDirty();
                            }),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                // 明暗自适应：原先写死 primary 底 + Colors.white，
                                // 暗色下变成「白底 + 浅字」，几乎不可读（U6 真机发现）
                                color: selected
                                    ? context.ibd.brandInk
                                    : (ideal
                                        ? context.ibd.brandSoft
                                        : context.ibd.surface),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? context.ibd.brandInk
                                      : context.ibd.divider,
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
                                          ? context.ibd.onBrand
                                          : context.ibd.textPrimary,
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
                                            ? context.ibd.onBrand
                                            : context.ibd.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (ideal && !selected)
                                    Text(
                                      '理想',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: context.ibd.brandInk,
                                      ),
                                    ),
                                ],
                              ),
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
                          ? context.ibd.success
                          : context.ibd.textSecondary,
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
                      Text(
                        '与排便细表同一套分级，打卡保存后自动写入细表历史。',
                        style: _hintStyle,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IbdChoiceChip(
                            expanded: true,
                            label: '无',
                            selected: _blood == 'none',
                            color: context.ibd.success,
                            onTap: () => setState(() {
                              _blood = 'none';
                              _markDirty();
                            }),
                          ),
                          const SizedBox(width: 8),
                          IbdChoiceChip(
                            expanded: true,
                            label: '擦拭有',
                            selected: _blood == 'trace',
                            color: context.ibd.warning,
                            onTap: () => setState(() {
                              _blood = 'trace';
                              _markDirty();
                            }),
                          ),
                          const SizedBox(width: 8),
                          IbdChoiceChip(
                            expanded: true,
                            label: '明显',
                            selected: _blood == 'obvious',
                            color: context.ibd.danger,
                            onTap: () => setState(() {
                              _blood = 'obvious';
                              _markDirty();
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
                          _markDirty();
                        }),
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        label: '黏液',
                        hint: '大便带黏液或鼻涕状分泌物',
                        value: _mucus,
                        onChanged: (v) => setState(() {
                          _mucus = v;
                          _markDirty();
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
                              Text(
                                '今日排便细表记录',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: context.ibd.brandInk,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _todayBathSummary!,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: context.ibd.textSecondary,
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
                        label: '腹胀明显',
                        hint: '肚子胀气、发紧或鼓胀',
                        value: _bloatingFlag,
                        onChanged: (v) => setState(() {
                          _bloatingFlag = v;
                          _markDirty();
                        }),
                      ),
                      if (_bloatingFlag) ...[
                        const SizedBox(height: 8),
                        Text('腹胀 ${_bloating.round()} / 10', style: _hintStyle),
                        Slider(
                          key: const Key('symptom-bloating-slider'),
                          value: _bloating,
                          max: 10,
                          divisions: 10,
                          onChanged: (v) => setState(() {
                            _bloating = v;
                            _markDirty();
                          }),
                        ),
                      ],
                      const Divider(height: 1),
                      _SwitchRow(
                        label: '恶心',
                        hint: '想吐或胃里翻腾',
                        value: _nausea,
                        onChanged: (v) => setState(() {
                          _nausea = v;
                          _markDirty();
                        }),
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        label: '疲劳感明显',
                        hint: '比平时更没劲、容易累',
                        value: _fatigueFlag,
                        onChanged: (v) => setState(() {
                          _fatigueFlag = v;
                          _markDirty();
                        }),
                      ),
                      if (_fatigueFlag) ...[
                        const SizedBox(height: 8),
                        Text('疲劳 ${_fatigue.round()} / 10', style: _hintStyle),
                        Slider(
                          key: const Key('symptom-fatigue-slider'),
                          value: _fatigue,
                          max: 10,
                          divisions: 10,
                          onChanged: (v) => setState(() {
                            _fatigue = v;
                            _markDirty();
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
                          _markDirty();
                        }),
                      ),
                      const Divider(height: 1),
                      _SwitchRow(
                        label: '关节痛',
                        hint: '关节酸痛或肿胀',
                        value: _jointPain,
                        onChanged: (v) => setState(() {
                          _jointPain = v;
                          _markDirty();
                        }),
                      ),
                      if (_jointPain) ...[
                        const SizedBox(height: 4),
                        Text('部位（可多选）', style: _hintStyle),
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
                                  _markDirty();
                                }),
                                selectedColor:
                                    IbdColors.primary.withValues(alpha: 0.18),
                                checkmarkColor: context.ibd.brandInk,
                                labelStyle: TextStyle(
                                  color: _jointSites.contains(site)
                                      ? context.ibd.brandInk
                                      : context.ibd.textPrimary,
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
                                      _markDirty();
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
                      color: context.ibd.textSecondary,
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
                          _markDirty();
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text('睡眠质量', style: _hintStyle),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var q = 1; q <= 5; q++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: IbdScoreChip(
                                score: q,
                                selected: _sleepQuality == q,
                                onTap: () => setState(() {
                                  _sleepQuality = q;
                                  _wellnessTouched = true;
                                  _markDirty();
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
                          _markDirty();
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
                              // 无 tooltip 的 IconButton 读屏只念「按钮」，
                              // 不知道是加还是减（U8 语义守卫测试抓到的）
                              tooltip: '减少夜醒次数',
                              onPressed: _nightWakes > 0
                                  ? () => setState(() {
                                        _nightWakes--;
                                        _wellnessTouched = true;
                                        _markDirty();
                                      })
                                  : null,
                              icon: const Icon(Icons.remove_rounded),
                            ),
                            IconButton(
                              tooltip: '增加夜醒次数',
                              onPressed: _nightWakes < 10
                                  ? () => setState(() {
                                        _nightWakes++;
                                        _wellnessTouched = true;
                                        _markDirty();
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
                          _markDirty();
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text('压力来源（可空）', style: _hintStyle),
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
                                _markDirty();
                              }),
                              selectedColor:
                                  IbdColors.primary.withValues(alpha: 0.18),
                              labelStyle: TextStyle(
                                color: _stressSource == s
                                    ? context.ibd.brandInk
                                    : context.ibd.textPrimary,
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
                      Text(
                        '和昨天比，今天整体怎么样？选一个最接近的。',
                        style: _hintStyle,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IbdChoiceChip(
                            expanded: true,
                            label: '比昨天差',
                            selected: _feeling == 'worse',
                            color: context.ibd.danger,
                            onTap: () => setState(() {
                              _feeling = 'worse';
                              _markDirty();
                            }),
                          ),
                          const SizedBox(width: 8),
                          IbdChoiceChip(
                            expanded: true,
                            label: '差不多',
                            selected: _feeling == 'same',
                            color: context.ibd.warning,
                            onTap: () => setState(() {
                              _feeling = 'same';
                              _markDirty();
                            }),
                          ),
                          const SizedBox(width: 8),
                          IbdChoiceChip(
                            expanded: true,
                            label: '比昨天好',
                            selected: _feeling == 'better',
                            color: context.ibd.success,
                            onTap: () => setState(() {
                              _feeling = 'better';
                              _markDirty();
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_saved && _syncedToBathroom)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '排便细项已同步到「分析 · 排便细表」，无需再填一遍。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.ibd.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
    );
  }
}

/// U4：底部吸附保存条。常驻拇指区，并显式反馈草稿状态，
/// 消除"滚了 4 屏才找到保存 / 中途退出全白填"的顾虑。
class _CheckinSaveBar extends StatelessWidget {
  const _CheckinSaveBar({
    required this.saved,
    required this.draftRestored,
    required this.draftSavedAt,
    required this.onSave,
  });

  final bool saved;
  final bool draftRestored;
  final DateTime? draftSavedAt;
  final Future<void> Function() onSave;

  String get _hint {
    if (saved) return '已保存到本机 · 可随时修改';
    if (draftRestored) return '已恢复上次未保存的草稿';
    final at = draftSavedAt;
    if (at != null) {
      final hh = at.hour.toString().padLeft(2, '0');
      final mm = at.minute.toString().padLeft(2, '0');
      return '草稿已自动保存 $hh:$mm · 仅存本机';
    }
    return '离开页面会自动存草稿 · 仅存本机';
  }

  @override
  Widget build(BuildContext context) {
    // U6：吸附栏骨架统一走 IbdStickyAction，这里只负责文案与图标
    return IbdStickyAction(
      label: saved ? '已保存到本机' : '保存今日打卡',
      icon: saved ? Icons.check_circle_rounded : Icons.edit_rounded,
      hint: _hint,
      onPressed: () => onSave(),
    );
  }
}


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
    // U6：卡片骨架统一走 IbdCard，这里只描述内容
    return IbdCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: context.ibd.textPrimary,
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
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.ibd.brandInk,
              ),
            ),
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
        Text(label, style: TextStyle(fontSize: 11, color: context.ibd.textSecondary)),
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

  Color _colorFor(BuildContext context, DateTime day, bool isToday) {
    final sev = severityByDate[_iso(day)];
    if (sev == null) return context.ibd.divider;
    switch (severityBand(sev)) {
      case 'green':
        return context.ibd.success;
      case 'warning':
        return context.ibd.warning;
      default:
        return context.ibd.danger;
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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.ibd.textSecondary,
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
                      final sev = severityByDate[iso];
                      final color = _colorFor(context, day, isToday);
                      // 颜色之外的第二重编码：有记录时格内直接显示严重度数值。
                      // 灰度截图 / 色盲下「5 下面有个 7」仍能读出这一档有多重，
                      // 只靠红黄绿是读不出来的（WCAG 1.4.1）。
                      final bandText = sev == null
                          ? '无记录'
                          : '严重度 ${sev.round()}，${severityBandText(sev)}';
                      return Semantics(
                        button: true,
                        selected: isSel,
                        label: '${day.month} 月 ${day.day} 日，$bandText'
                            '${isToday ? '，今天' : ''}',
                        // excludeSemantics 会连 InkWell 的 tap 动作一起丢掉，
                        // 这里补回来，否则读屏念「按钮」但双击没反应
                        onTap: () => onSelect(iso, sev),
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: () => onSelect(iso, sev),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            // 40 + 上下各 2 的外边距 = 44，满足最小触控区
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isToday || isSel
                                    ? context.ibd.brandInk
                                    : Colors.transparent,
                                width: isToday || isSel ? 1.5 : 0,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.1,
                                    fontWeight: isToday
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    // 有记录的格子用 onBrand：浅色档位是深底配白字，
                                    // 暗色档位是亮底配深字（白字在亮绿/亮黄上读不出）
                                    color: sev == null
                                        ? context.ibd.textSecondary
                                        : context.ibd.onBrand,
                                  ),
                                ),
                                if (sev != null)
                                  Text(
                                    '${sev.round()}',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      height: 1.1,
                                      fontWeight: FontWeight.w800,
                                      color: context.ibd.onBrand,
                                    ),
                                  ),
                              ],
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
