import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/ui/theme.dart';

/// D3：检查影像 / 手术本地录入
class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final _exams = ExamRepository();
  final _surgeries = SurgeryRepository();
  List<Map<String, dynamic>> _examList = [];
  List<Map<String, dynamic>> _surgList = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await _exams.listAll();
    final s = await _surgeries.listAll();
    if (!mounted) return;
    setState(() {
      _examList = e;
      _surgList = s;
    });
  }

  Future<void> _addExam() async {
    final date = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    final type = TextEditingController(text: '腹部超声');
    final part = TextEditingController();
    final findings = TextEditingController();
    final score = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增检查'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: date, decoration: const InputDecoration(labelText: '日期')),
              TextField(controller: type, decoration: const InputDecoration(labelText: '类型')),
              TextField(controller: part, decoration: const InputDecoration(labelText: '部位')),
              TextField(controller: findings, decoration: const InputDecoration(labelText: '所见')),
              TextField(controller: score, decoration: const InputDecoration(labelText: '评分（可选）')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    await _exams.insert(
      date: date.text.trim(),
      type: type.text.trim(),
      bodyPart: part.text.trim(),
      findings: findings.text.trim(),
      score: score.text.trim(),
    );
    await _load();
  }

  Future<void> _addSurgery() async {
    final date = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    final type = TextEditingController(text: '切除');
    final part = TextEditingController(text: '小肠');
    final procedure = TextEditingController();
    final surgeon = TextEditingController();
    final length = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增手术'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: date, decoration: const InputDecoration(labelText: '日期')),
              TextField(controller: type, decoration: const InputDecoration(labelText: '类型')),
              TextField(controller: part, decoration: const InputDecoration(labelText: '部位')),
              TextField(controller: procedure, decoration: const InputDecoration(labelText: '术式')),
              TextField(controller: surgeon, decoration: const InputDecoration(labelText: '主刀')),
              TextField(controller: length, decoration: const InputDecoration(labelText: '切除长度 cm（可选）')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final n = double.tryParse(length.text.trim());
    await _surgeries.insert(
      date: date.text.trim(),
      type: type.text.trim(),
      bodyPart: part.text.trim(),
      procedure: procedure.text.trim(),
      surgeon: surgeon.text.trim(),
      resectedLengthCm: n,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(title: const Text('检查与手术')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _addExam,
                  icon: const Icon(Icons.monitor_heart_rounded),
                  label: const Text('检查'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _addSurgery,
                  icon: const Icon(Icons.local_hospital_rounded),
                  label: const Text('手术'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('检查', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          if (_examList.isEmpty) const Text('暂无', style: TextStyle(color: IbdColors.textSecondary)),
          ..._examList.map((e) => Card(
                child: ListTile(
                  leading: const Icon(Icons.monitor_heart_rounded),
                  title: Text('${e['type']} ${e['body_part'] ?? ''}'),
                  subtitle: Text(
                    '${e['date']}\n${e['findings'] ?? ''} ${e['score'] ?? ''}',
                  ),
                  isThreeLine: true,
                ),
              )),
          const SizedBox(height: 16),
          const Text('手术', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          if (_surgList.isEmpty) const Text('暂无', style: TextStyle(color: IbdColors.textSecondary)),
          ..._surgList.map((s) => Card(
                child: ListTile(
                  leading: const Icon(Icons.local_hospital_rounded),
                  title: Text('${s['type'] ?? ''} · ${s['body_part'] ?? ''}'),
                  subtitle: Text(
                    '${s['date']}\n${s['procedure'] ?? ''} · ${s['surgeon'] ?? ''}'
                    '${s['resected_length_cm'] != null ? '\n切除 ${s['resected_length_cm']} cm' : ''}',
                  ),
                  isThreeLine: true,
                ),
              )),
        ],
      ),
    );
  }
}

/// D4：排便细表
class BathroomPage extends StatefulWidget {
  const BathroomPage({super.key, this.repo});

  /// 测试可注入仓库；生产默认走本机 LocalDb。
  final BathroomRepository? repo;

  @override
  State<BathroomPage> createState() => _BathroomPageState();
}

class _BathroomPageState extends State<BathroomPage> {
  late final BathroomRepository _repo = widget.repo ?? BathroomRepository();
  List<Map<String, dynamic>> _rows = [];
  int _stoolType = 4;
  bool _urgency = false;
  bool _blood = false;
  bool _mucus = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _repo.listAll();
    if (!mounted) return;
    setState(() => _rows = rows);
  }

  Future<void> _add() async {
    final n = DateTime.now();
    final date =
        '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    final time =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
    await _repo.insert(
      date: date,
      time: time,
      stoolType: _stoolType,
      urgency: _urgency,
      blood: _blood,
      mucus: _mucus,
      notes: '排便细表手记',
    );
    await _load();
  }

  static String _bloodText(Object? flag) {
    switch (flag) {
      case 1:
        return '擦拭有血';
      case 2:
        return '明显便血';
      case 0:
        return '';
      default:
        return '';
    }
  }

  static String _sourceBadge(Object? source) {
    return '${source ?? 'manual'}' == 'checkin' ? '打卡同步' : '细表手记';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(title: const Text('排便记录')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IbdColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bristol $_stoolType 型',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                  value: _stoolType.toDouble(),
                  min: 1,
                  max: 7,
                  divisions: 6,
                  onChanged: (v) => setState(() => _stoolType = v.round()),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('紧迫感'),
                        value: _urgency,
                        onChanged: (v) => setState(() => _urgency = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('便血'),
                        value: _blood,
                        onChanged: (v) => setState(() => _blood = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('黏液'),
                        value: _mucus,
                        onChanged: (v) => setState(() => _mucus = v),
                      ),
                    ],
                  ),
                ),
                FilledButton(onPressed: _add, child: const Text('记一笔')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('历史', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            '完成「今日打卡」会自动写入对应历史，无需在本页重复填写。',
            style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
          ),
          const SizedBox(height: 8),
          if (_rows.isEmpty)
            const Text('暂无记录', style: TextStyle(color: IbdColors.textSecondary)),
          ..._rows.map((r) {
            final fromCheckin = '${r['source'] ?? 'manual'}' == 'checkin';
            final bloodText = _bloodText(r['blood']);
            final details = StringBuffer('Bristol ${r['stool_type'] ?? '—'}');
            if (r['daily_count'] != null) {
              details.write(' · 当日累计 ${r['daily_count']} 次');
            }
            if (r['diarrhea_count'] != null) {
              details.write(' · 腹泻 ${r['diarrhea_count']} 次');
            }
            if (r['urgency'] == 1) details.write(' · 紧迫');
            if (bloodText.isNotEmpty) details.write(' · $bloodText');
            if (r['mucus'] == 1) details.write(' · 黏液');
            return Card(
              child: ListTile(
                dense: true,
                title: Row(
                  children: [
                    Expanded(
                      child: Text('${r['date']} ${r['time'] ?? ''}'),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: fromCheckin
                            ? const Color(0xFFCCFBF1)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _sourceBadge(r['source']),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: fromCheckin
                              ? IbdColors.primaryDark
                              : IbdColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(details.toString()),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// D6 部分：本地就诊摘要
class VisitSummaryPage extends StatefulWidget {
  const VisitSummaryPage({super.key});

  @override
  State<VisitSummaryPage> createState() => _VisitSummaryPageState();
}

class _VisitSummaryPageState extends State<VisitSummaryPage> {
  String _summary = '';

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    final meds = await MedicationRepository().listCurrent();
    final labs = await LabRepository().listAll();
    final latest = await LabSeriesRepository().latestCore();
    final inj = await InjectionRepository().listPending(withinDays: 21);
    final symptoms = await SymptomRepository().listAll();

    final labLine = latest.entries
        .map((e) => '${e.key}=${e.value['value']}${e.value['unit'] ?? ''}')
        .join('  ');
    final medLine = meds
        .map((m) => '${m['drug_name']} ${m['dosage']} ${m['frequency']}')
        .join('\n');
    final lastSym = symptoms.isNotEmpty ? symptoms.first : null;

    final sb = StringBuffer();
    sb.writeln('【就诊摘要 · IBDers 本地生成】');
    sb.writeln('日期：${DateTime.now().toIso8601String().substring(0, 10)}');
    sb.writeln();
    sb.writeln('【当前用药】');
    sb.writeln(medLine.isEmpty ? '（未记录）' : medLine);
    sb.writeln();
    sb.writeln('【最近检验（${labs.isNotEmpty ? labs.first['date'] : '无'}）】');
    sb.writeln(labLine.isEmpty ? '（未录入核心指标）' : labLine);
    sb.writeln();
    sb.writeln('【近期注射】');
    if (inj.isEmpty) {
      sb.writeln('（21 天内无待注射）');
    } else {
      for (final r in inj.take(3)) {
        sb.writeln('${r['drug']} ${r['planned_date']} ${r['dose']}');
      }
    }
    sb.writeln();
    sb.writeln('【症状】');
    if (lastSym == null) {
      sb.writeln('（今日未打卡）');
    } else {
      final bloodLabel = switch ('${lastSym['bloody_stool'] ?? 'none'}') {
        'obvious' => '明显',
        'trace' => '擦拭有',
        _ => '无',
      };
      final urgency = lastSym['urgency'] == 1 ? '紧迫' : '无紧迫';
      final mucus = lastSym['mucus'] == 1 ? '有黏液' : '无黏液';
      final bowel = lastSym['bowel_count'] ?? lastSym['diarrhea_count'];
      sb.writeln(
        '腹痛 ${lastSym['pain_level']}/10 · 排便 $bowel 次 · 腹泻 ${lastSym['diarrhea_count']} 次 · '
        'Bristol ${lastSym['stool_type']} · 便血 $bloodLabel · $urgency · $mucus',
      );
    }
    sb.writeln();
    sb.writeln('【关注】');
    sb.writeln('- 数据均来自本机，请结合医生建议解读');

    setState(() => _summary = sb.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(title: const Text('就诊摘要')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: IbdColors.card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _summary,
                    style: const TextStyle(height: 1.5, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _build,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新生成'),
            ),
          ],
        ),
      ),
    );
  }
}
