import '../db/repositories.dart';

/// 年度报告（PRD V1.5）：汇总一年病程，生成可分享文本/JSON。
class AnnualReportBuilder {
  AnnualReportBuilder({
    LabRepository? labs,
    MedicationRepository? meds,
    SymptomRepository? symptoms,
    InjectionRepository? injections,
  })  : _labs = labs ?? LabRepository(),
        _meds = meds ?? MedicationRepository(),
        _symptoms = symptoms ?? SymptomRepository(),
        _injections = injections ?? InjectionRepository();

  final LabRepository _labs;
  final MedicationRepository _meds;
  final SymptomRepository _symptoms;
  final InjectionRepository _injections;

  Future<AnnualReport> build({int? year}) async {
    final y = year ?? DateTime.now().year;
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

    return AnnualReport(
      year: y,
      labCount: labs.length,
      medChanges: meds.length,
      symptomDays: symptoms.length,
      injectionCount: injections.length,
      avgPain: _avgPain(symptoms),
      labs: labs,
      meds: meds,
    );
  }

  double? _avgPain(List<Map<String, dynamic>> symptoms) {
    final vals = symptoms
        .map((s) => s['painLevel'])
        .whereType<num>()
        .map((e) => e.toDouble())
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }
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
  });

  final int year;
  final int labCount;
  final int medChanges;
  final int symptomDays;
  final int injectionCount;
  final double? avgPain;
  final List<Map<String, dynamic>> labs;
  final List<Map<String, dynamic>> meds;

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
      };
}
