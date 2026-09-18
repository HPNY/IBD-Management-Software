import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/repositories.dart';

/// 本地 CSV 导出：检验 / 用药 / 症状 / 排便 / 量表。
class DataExporter {
  final _labs = LabRepository();
  final _meds = MedicationRepository();
  final _symptoms = SymptomRepository();
  final _bath = BathroomRepository();
  final _qol = QualitySurveyRepository();

  static String _csv(List<List<String>> rows) {
    return rows.map((r) {
      return r.map((c) {
        final s = c.replaceAll('"', '""');
        return s.contains(',') || s.contains('"') || s.contains('\n')
            ? '"$s"'
            : s;
      }).join(',');
    }).join('\n');
  }

  Future<String> exportLabsCsv() async {
    final labs = await _labs.listAll();
    final rows = <List<String>>[
      ['lab_id', 'date', 'hospital', 'source', 'item', 'value', 'unit', 'flag'],
    ];
    for (final lab in labs) {
      final items = (lab['items'] as List?) ?? [];
      if (items.isEmpty) {
        rows.add([
          '${lab['id']}',
          '${lab['date']}',
          '${lab['hospital'] ?? ''}',
          '${lab['source'] ?? ''}',
          '',
          '',
          '',
          '',
        ]);
      }
      for (final it in items) {
        final m = Map<String, dynamic>.from(it as Map);
        rows.add([
          '${lab['id']}',
          '${lab['date']}',
          '${lab['hospital'] ?? ''}',
          '${lab['source'] ?? ''}',
          '${m['name_norm'] ?? m['name'] ?? ''}',
          '${m['value'] ?? ''}',
          '${m['unit'] ?? ''}',
          '${m['flag'] ?? ''}',
        ]);
      }
    }
    return _csv(rows);
  }

  Future<String> exportMedicationsCsv() async {
    final rows = <List<String>>[
      ['id', 'drug', 'dosage', 'frequency', 'route', 'start', 'end', 'status', 'reason'],
    ];
    for (final m in await _meds.listAll()) {
      rows.add([
        '${m['id']}',
        '${m['drug_name']}',
        '${m['dosage']}',
        '${m['frequency']}',
        '${m['route']}',
        '${m['start_date']}',
        '${m['end_date'] ?? ''}',
        '${m['status']}',
        '${m['reason'] ?? ''}',
      ]);
    }
    return _csv(rows);
  }

  Future<String> exportSymptomsCsv() async {
    final rows = <List<String>>[
      [
        'date',
        'pain',
        'diarrhea',
        'bristol',
        'bloody',
        'fatigue',
        'nausea',
        'feeling',
      ],
    ];
    for (final s in await _symptoms.listAll()) {
      rows.add([
        '${s['date']}',
        '${s['pain_level'] ?? ''}',
        '${s['diarrhea_count'] ?? ''}',
        '${s['stool_type'] ?? ''}',
        '${s['bloody_stool'] ?? ''}',
        '${s['fatigue'] ?? ''}',
        '${s['nausea'] ?? ''}',
        '${s['overall_feeling'] ?? ''}',
      ]);
    }
    return _csv(rows);
  }

  Future<String> exportSurveysCsv() async {
    final rows = <List<String>>[
      ['date', 'kind', 'total', 'band'],
    ];
    for (final s in await _qol.listAll()) {
      rows.add([
        '${s['date']}',
        '${s['kind']}',
        '${s['total']}',
        '${s['detail_json'] ?? ''}',
      ]);
    }
    return _csv(rows);
  }

  /// 导出多表到 zip 目录并系统分享。
  Future<String> exportAllAndShare() async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final folder = Directory('${dir.path}/ibders_export_$ts');
    await folder.create(recursive: true);

    final files = <String, String>{
      'labs.csv': await exportLabsCsv(),
      'medications.csv': await exportMedicationsCsv(),
      'symptoms.csv': await exportSymptomsCsv(),
      'surveys.csv': await exportSurveysCsv(),
    };
    final paths = <String>[];
    for (final e in files.entries) {
      final f = File('${folder.path}/${e.key}');
      await f.writeAsString(e.value, flush: true);
      paths.add(f.path);
    }

    await Share.shareXFiles(
      paths.map((p) => XFile(p)).toList(),
      text: 'IBDers 数据导出（本机生成，未上传）',
    );
    return folder.path;
  }

  Future<Map<String, dynamic>> buildJsonBundle() async {
    return {
      'format': 'ibders.export.v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'labs': await _labs.listAll(),
      'medications': await _meds.listAll(),
      'symptoms': await _symptoms.listAll(),
      'bathroom': await _bath.listAll(),
      'surveys': await _qol.listAll(),
    };
  }

  static String encodeJson(Map<String, dynamic> data) =>
      const JsonEncoder.withIndent('  ').convert(data);
}
