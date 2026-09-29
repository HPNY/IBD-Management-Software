import '../db/repositories.dart';

/// 年度报告（PRD V1.5 G3）：汇总一年病程 + 同比 + 检查/手术汇总。
class AnnualReportBuilder {
  AnnualReportBuilder({
    LabRepository? labs,
    MedicationRepository? meds,
    SymptomRepository? symptoms,
    InjectionRepository? injections,
    ExamRepository? exams,
    SurgeryRepository? surgeries,
  })  : _labs = labs ?? LabRepository(),
        _meds = meds ?? MedicationRepository(),
        _symptoms = symptoms ?? SymptomRepository(),
        _injections = injections ?? InjectionRepository(),
        _exams = exams ?? ExamRepository(),
        _surgeries = surgeries ?? SurgeryRepository();

  final LabRepository _labs;
  final MedicationRepository _meds;
  final SymptomRepository _symptoms;
  final InjectionRepository _injections;
  final ExamRepository _exams;
  final SurgeryRepository _surgeries;

  /// 默认展示的「最近完整年份」：进入 1 月仍展示去年，其余时间展示去年。
  /// （今年尚未结束 → 上一年为最近完整年；语义上 year-1 恒为完整年。）
  static int defaultRecentCompleteYear({DateTime? now}) {
    final y = (now ?? DateTime.now()).year;
    return y - 1;
  }

  Future<AnnualReport> build({int? year}) async {
    final y = year ?? defaultRecentCompleteYear();
    final cur = await _buildYear(y);
    // 同比：上一年（无数据时 prev 各计数为 0）
    final prev = await _buildYear(y - 1);
    return cur..prev = prev;
  }

  Future<AnnualReport> _buildYear(int y) async {
    final start = '$y-01-01';
    final end = '$y-12-31';

    final allLabs = await _labs.listAll();
    final labs = allLabs.where((l) {
      final d = '${l['date']}';
      return d.compareTo(start) >= 0 && d.compareTo(end) <= 0;
    }).toList();

    final allMeds = await _meds.listAll();
    final meds = allMeds.where((m) {
      final s = '${m['startDate'] ?? ''}';
      final e = '${m['endDate'] ?? ''}';
      return s.isNotEmpty &&
          s.compareTo(end) <= 0 &&
          (e.isEmpty || e.compareTo(start) >= 0);
    }).toList();

    final allSym = await _symptoms.listAll();
    final symptoms = allSym.where((s) {
      final d = '${s['date']}';
      return d.compareTo(start) >= 0 && d.compareTo(end) <= 0;
    }).toList();

    final allInj = await _injections.listAll();
    final injections = allInj.where((i) {
      final d = '${i['plannedDate'] ?? i['actualDate'] ?? ''}';
      return d.isNotEmpty && d.compareTo(start) >= 0 && d.compareTo(end) <= 0;
    }).toList();

    final allExams = await _exams.listAll();
    final examRows = allExams.where((e) {
      final d = '${e['date']}';
      return d.compareTo(start) >= 0 && d.compareTo(end) <= 0;
    }).toList();

    final allSurg = await _surgeries.listAll();
    final surgeryRows = allSurg.where((s) {
      final d = '${s['date']}';
      return d.compareTo(start) >= 0 && d.compareTo(end) <= 0;
    }).toList();

    return AnnualReport(
      year: y,
      labCount: labs.length,
      medChanges: meds.length,
      symptomDays: symptoms.length,
      injectionCount: injections.length,
      avgPain: _avgPain(symptoms),
      labs: labs,
      meds: meds,
      exams: examRows,
      surgeries: surgeryRows,
    );
  }

  double? _avgPain(List<Map<String, dynamic>> symptoms) {
    final vals = symptoms
        .map((s) => s['painLevel'] ?? s['pain_level'])
        .whereType<num>()
        .map((e) => e.toDouble())
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }
}

/// 同比差值（本年 − 上年）。null 表示任一侧缺失均值。
class CompareDelta {
  const CompareDelta({
    required this.labCount,
    required this.symptomDays,
    required this.injectionCount,
    required this.avgPain,
  });

  final int labCount;
  final int symptomDays;
  final int injectionCount;
  final double? avgPain;

  static String _sign(int v) => v > 0 ? '+$v' : '$v';

  String get summary =>
      '检验 ${_sign(labCount)} · 打卡天 ${_sign(symptomDays)} · '
      '注射 ${_sign(injectionCount)}'
      '${avgPain == null ? '' : ' · 平均腹痛 ${avgPain! >= 0 ? '+' : ''}${avgPain!.toStringAsFixed(1)}'}';
}

class AnnualReport {
  AnnualReport({
    required this.year,
    required this.labCount,
    required this.medChanges,
    required this.symptomDays,
    required this.injectionCount,
    required this.avgPain,
    required this.labs,
    required this.meds,
    List<Map<String, dynamic>>? exams,
    List<Map<String, dynamic>>? surgeries,
  })  : exams = exams ?? const [],
        surgeries = surgeries ?? const [];

  final int year;
  final int labCount;
  final int medChanges;
  final int symptomDays;
  final int injectionCount;
  final double? avgPain;
  final List<Map<String, dynamic>> labs;
  final List<Map<String, dynamic>> meds;
  final List<Map<String, dynamic>> exams;
  final List<Map<String, dynamic>> surgeries;

  /// 上一年度报告（build 时填充；手建时可为 null）。
  AnnualReport? prev;

  CompareDelta? get delta {
    final p = prev;
    if (p == null) return null;
    return CompareDelta(
      labCount: labCount - p.labCount,
      symptomDays: symptomDays - p.symptomDays,
      injectionCount: injectionCount - p.injectionCount,
      avgPain: (avgPain == null || p.avgPain == null)
          ? null
          : avgPain! - p.avgPain!,
    );
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  String toText() {
    final b = StringBuffer()
      ..writeln('IBDers $year 年度报告')
      ..writeln('生成时间：${DateTime.now().toIso8601String().substring(0, 19)}')
      ..writeln('—— 概览 ——')
      ..writeln('检验记录：$labCount 次')
      ..writeln('用药变更：$medChanges 条')
      ..writeln('症状打卡：$symptomDays 天')
      ..writeln('注射针次：$injectionCount 次')
      ..writeln(
        '平均腹痛：${avgPain == null ? '—' : avgPain!.toStringAsFixed(1)} / 10',
      );

    final d = delta;
    b.writeln('—— 与上一年度（${year - 1}）对比 ——');
    if (d == null) {
      b.writeln('（未生成上年数据）');
    } else {
      b.writeln(d.summary);
      if (prev != null) {
        b.writeln(
          '上年基线：检验 ${prev!.labCount} · 打卡天 ${prev!.symptomDays} · '
          '注射 ${prev!.injectionCount}',
        );
      }
    }

    b.writeln('—— 用药 ——');
    if (meds.isEmpty) {
      b.writeln('（本年度无用药记录）');
    } else {
      for (final m in meds) {
        b.writeln(
          '· ${m['drugName'] ?? ''} ${m['dosage'] ?? ''} '
          '(${m['startDate']} ~ ${m['endDate'] ?? '至今'}) ${m['status'] ?? ''}',
        );
      }
    }

    b.writeln('—— 检查汇总（${exams.length}）——');
    if (exams.isEmpty) {
      b.writeln('（本年度无检查记录）');
    } else {
      for (final e in exams) {
        b.writeln(
          '· ${e['date']} ${e['type'] ?? ''} '
          '${_clip('${e['findings'] ?? e['diagnosis'] ?? ''}', 80)}'
          '${e['score'] == null || '${e['score']}'.isEmpty ? '' : ' · ${e['score']}'}',
        );
      }
    }

    b.writeln('—— 手术汇总（${surgeries.length}）——');
    if (surgeries.isEmpty) {
      b.writeln('（本年度无手术记录）');
    } else {
      for (final s in surgeries) {
        b.writeln(
          '· ${s['date']} ${s['type'] ?? s['procedure'] ?? ''} '
          '${_clip('${s['findings'] ?? s['notes'] ?? ''}', 80)}',
        );
      }
    }

    b.writeln('—— 备注 ——');
    b.writeln('数据仅存本机；分享前请自行核对。不构成诊疗建议。');
    return b.toString();
  }

  Map<String, dynamic> toJson() => {
        'year': year,
        'labCount': labCount,
        'medChanges': medChanges,
        'symptomDays': symptomDays,
        'injectionCount': injectionCount,
        'avgPain': avgPain,
        'meds': meds,
        'examCount': exams.length,
        'surgeryCount': surgeries.length,
        'delta': delta == null
            ? null
            : {
                'labCount': delta!.labCount,
                'symptomDays': delta!.symptomDays,
                'injectionCount': delta!.injectionCount,
                'avgPain': delta!.avgPain,
              },
        'prevYear': prev?.year,
      };
}
