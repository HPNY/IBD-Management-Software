import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'local_db.dart';

class LabRepository {
  Future<Database> get _db => LocalDb.instance.database;

  Future<String> insert({
    required String date,
    String? hospital,
    String source = 'manual',
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await _db;
    final labId = const Uuid().v4();
    await db.transaction((txn) async {
      await txn.insert('labs', {
        'id': labId,
        'date': date,
        'hospital': hospital,
        'source': source,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final it in items) {
        await txn.insert('lab_items', {
          'id': const Uuid().v4(),
          'lab_id': labId,
          'name_norm': it['nameNorm'] ?? it['name'] ?? '',
          'name_raw': it['nameRaw'] ?? it['name_norm'] ?? it['name'] ?? '',
          'value': it['value'],
          'unit': it['unit'],
          'ref_min': it['refMin'] ?? it['ref_min'],
          'ref_max': it['refMax'] ?? it['ref_max'],
          'flag': it['flag'],
        });
      }
    });
    return labId;
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final db = await _db;
    final labs = await db.query('labs', orderBy: 'date DESC');
    final items = await db.query('lab_items');
    return labs.map((lab) {
      final id = lab['id'] as String;
      return {
        ...lab,
        'items': items.where((i) => i['lab_id'] == id).toList(),
      };
    }).toList();
  }
}

class MedicationRepository {
  Future<Database> get _db => LocalDb.instance.database;

  Future<List<Map<String, dynamic>>> listCurrent() async {
    final db = await _db;
    return db.query(
      'medications',
      where: "status IN ('active','paused')",
      orderBy: 'start_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final db = await _db;
    return db.query('medications', orderBy: 'start_date DESC');
  }

  Future<String> insert(Map<String, dynamic> row) async {
    final db = await _db;
    final id = const Uuid().v4();
    await db.insert('medications', {
      'id': id,
      'drug_name': row['drugName'],
      'brand_name': row['brandName'],
      'category': row['category'],
      'dosage': row['dosage'],
      'frequency': row['frequency'],
      'route': row['route'],
      'start_date': row['startDate'],
      'end_date': row['endDate'],
      'status': row['status'] ?? 'active',
      'reason': row['reason'],
    });
    return id;
  }

  Future<void> stop(String id, {String? reason, String? endDate}) async {
    final db = await _db;
    await db.update(
      'medications',
      {
        'status': 'stopped',
        'end_date': endDate ?? DateTime.now().toIso8601String().substring(0, 10),
        'reason': reason,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> addAdverseEvent({
    required String medicationId,
    required String title,
    String severity = 'mild',
    String? occurredAt,
    String? notes,
  }) async {
    final db = await _db;
    final id = const Uuid().v4();
    await db.insert('adverse_events', {
      'id': id,
      'medication_id': medicationId,
      'title': title,
      'severity': severity,
      'occurred_at': occurredAt ?? DateTime.now().toIso8601String().substring(0, 10),
      'notes': notes,
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> adverseEvents(String medicationId) async {
    final db = await _db;
    return db.query(
      'adverse_events',
      where: 'medication_id = ?',
      whereArgs: [medicationId],
      orderBy: 'occurred_at DESC',
    );
  }
}

class InjectionRepository {
  Future<Database> get _db => LocalDb.instance.database;

  Future<List<Map<String, dynamic>>> listAll() async {
    final db = await _db;
    return db.query('injections', orderBy: 'planned_date ASC');
  }

  Future<List<Map<String, dynamic>>> listPending({int withinDays = 60}) async {
    final all = await listAll();
    final now = DateTime.now();
    return all.where((r) {
      if (r['actual_date'] != null) return false;
      final planned = DateTime.tryParse('${r['planned_date']}');
      if (planned == null) return false;
      return planned.isBefore(now.add(Duration(days: withinDays)));
    }).toList();
  }

  Future<void> insertMany(List<Map<String, dynamic>> rows) async {
    final db = await _db;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('injections', {
        'id': row['id'] ?? const Uuid().v4(),
        'drug': row['drug'],
        'planned_date': row['plannedDate'],
        'actual_date': row['actualDate'],
        'phase': row['phase'],
        'dose': row['dose'],
        'route': row['route'],
        'week_number': row['weekNumber'],
        'notes': row['notes'],
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearPendingForDrug(String drug) async {
    final db = await _db;
    await db.delete(
      'injections',
      where: 'drug = ? AND actual_date IS NULL',
      whereArgs: [drug],
    );
  }

  Future<void> complete(String id, {String? actualDate}) async {
    final db = await _db;
    await db.update(
      'injections',
      {'actual_date': actualDate ?? DateTime.now().toIso8601String().substring(0, 10)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class SymptomRepository {
  Future<Database> get _db => LocalDb.instance.database;

  Future<void> upsert({
    required String date,
    int? painLevel,
    int? diarrheaCount,
    int? stoolType,
    String? bloodyStool,
    int? bloating,
    int? fatigue,
    bool? nausea,
    String? overallFeeling,
  }) async {
    final db = await _db;
    await db.insert(
      'symptom_diaries',
      {
        'id': const Uuid().v4(),
        'date': date,
        'pain_level': painLevel,
        'diarrhea_count': diarrheaCount,
        'stool_type': stoolType,
        'bloody_stool': bloodyStool,
        'bloating': bloating,
        'fatigue': fatigue,
        'nausea': nausea == null ? null : (nausea ? 1 : 0),
        'overall_feeling': overallFeeling,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final db = await _db;
    return db.query('symptom_diaries', orderBy: 'date DESC');
  }
}

class BathroomRepository {
  Future<Database> get _db => LocalDb.instance.database;

  Future<void> insert({
    required String date,
    String? time,
    int? stoolType,
    bool? urgency,
    bool? blood,
    bool? mucus,
    String? notes,
  }) async {
    final db = await _db;
    await db.insert('bathroom_records', {
      'id': const Uuid().v4(),
      'date': date,
      'time': time,
      'stool_type': stoolType,
      'urgency': urgency == null ? null : (urgency ? 1 : 0),
      'blood': blood == null ? null : (blood ? 1 : 0),
      'mucus': mucus == null ? null : (mucus ? 1 : 0),
      'notes': notes,
    });
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final db = await _db;
    return db.query('bathroom_records', orderBy: 'date DESC, time DESC');
  }
}

class ExamRepository {
  Future<Database> get _db => LocalDb.instance.database;

  Future<String> insert({
    required String date,
    required String type,
    String? bodyPart,
    String? findings,
    String? diagnosis,
    String? score,
    String? comparison,
  }) async {
    final db = await _db;
    final id = const Uuid().v4();
    await db.insert('exams', {
      'id': id,
      'date': date,
      'type': type,
      'body_part': bodyPart,
      'findings': findings,
      'diagnosis': diagnosis,
      'score': score,
      'comparison': comparison,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final db = await _db;
    return db.query('exams', orderBy: 'date DESC');
  }
}

class SurgeryRepository {
  Future<Database> get _db => LocalDb.instance.database;

  Future<String> insert({
    required String date,
    String? type,
    String? bodyPart,
    String? findings,
    String? procedure,
    double? resectedLengthCm,
    String? anastomosis,
    String? surgeon,
    String? notes,
  }) async {
    final db = await _db;
    final id = const Uuid().v4();
    await db.insert('surgeries', {
      'id': id,
      'date': date,
      'type': type,
      'body_part': bodyPart,
      'findings': findings,
      'procedure': procedure,
      'resected_length_cm': resectedLengthCm,
      'anastomosis': anastomosis,
      'surgeon': surgeon,
      'notes': notes,
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final db = await _db;
    return db.query('surgeries', orderBy: 'date DESC');
  }
}

/// 本地检验指标序列（趋势图）
class LabSeriesRepository {
  Future<Database> get _db => LocalDb.instance.database;

  /// 按规范名提取时间序列，如 CRP / 钙卫蛋白
  Future<List<Map<String, dynamic>>> seriesByName(String nameNorm) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT labs.date AS date, lab_items.value AS value, lab_items.unit AS unit
      FROM lab_items
      INNER JOIN labs ON labs.id = lab_items.lab_id
      WHERE lab_items.name_norm LIKE ?
      ORDER BY labs.date ASC
      ''',
      ['%$nameNorm%'],
    );
    return rows;
  }

  /// 汇总：最近一次各核心指标
  Future<Map<String, Map<String, dynamic>>> latestCore() async {
    const names = [
      '超敏C反应蛋白',
      '血沉',
      '粪便钙卫蛋白',
      '淋巴细胞',
      '白蛋白',
      '血红蛋白',
      '尿酸',
    ];
    final out = <String, Map<String, dynamic>>{};
    for (final n in names) {
      final s = await seriesByName(n);
      if (s.isNotEmpty) out[n] = s.last;
    }
    return out;
  }
}

/// 病程时间线：聚合本机事件
class TimelineRepository {
  Future<Database> get _db => LocalDb.instance.database;

  Future<List<Map<String, dynamic>>> events({int limit = 200}) async {
    final db = await _db;
    final out = <Map<String, dynamic>>[];

    final labs = await db.rawQuery(
      'SELECT date, hospital, source FROM labs ORDER BY date DESC LIMIT ?',
      [limit],
    );
    for (final r in labs) {
      out.add({
        'date': r['date'],
        'type': 'lab',
        'title': '检验 · ${r['hospital'] ?? ''}',
        'subtitle': '来源 ${r['source']}',
      });
    }

    final meds = await db.query('medications', orderBy: 'start_date DESC');
    for (final r in meds) {
      out.add({
        'date': r['start_date'],
        'type': 'med',
        'title': '用药 · ${r['drug_name']}',
        'subtitle': '${r['dosage']} ${r['frequency']}',
      });
      if (r['end_date'] != null) {
        out.add({
          'date': r['end_date'],
          'type': 'med_end',
          'title': '停药 · ${r['drug_name']}',
          'subtitle': '${r['reason'] ?? ''}',
        });
      }
    }

    final inj = await db.query('injections');
    for (final r in inj) {
      final d = r['actual_date'] ?? r['planned_date'];
      out.add({
        'date': d,
        'type': r['actual_date'] != null ? 'inj_done' : 'inj_plan',
        'title': '注射 · ${r['drug']}',
        'subtitle': '${r['dose']} W${r['week_number']}',
      });
    }

    final ex = await db.query('exams', orderBy: 'date DESC');
    for (final r in ex) {
      out.add({
        'date': r['date'],
        'type': 'exam',
        'title': '检查 · ${r['type']}',
        'subtitle': '${r['body_part'] ?? ''} ${r['score'] ?? ''}',
      });
    }

    final sg = await db.query('surgeries', orderBy: 'date DESC');
    for (final r in sg) {
      out.add({
        'date': r['date'],
        'type': 'surgery',
        'title': '手术 · ${r['type'] ?? ''}',
        'subtitle': '${r['body_part'] ?? ''} ${r['procedure'] ?? ''}',
      });
    }

    final qol = await db.query('quality_surveys', orderBy: 'date DESC');
    for (final r in qol) {
      out.add({
        'date': r['date'],
        'type': 'qol',
        'title': '量表 · ${r['kind']}',
        'subtitle': '${r['total']} 分',
      });
    }

    out.sort((a, b) => ('${b['date']}').compareTo('${a['date']}'));
    return out.take(limit).toList();
  }
}

/// 生活质量/心理量表（本地，v3）
class QualitySurveyRepository {
  Future<Database> get _db => LocalDb.instance.database;

  Future<String> save({
    required String date,
    required String kind,
    required int total,
    Map<String, dynamic>? detail,
  }) async {
    final db = await _db;
    final id = const Uuid().v4();
    await db.insert('quality_surveys', {
      'id': id,
      'date': date,
      'kind': kind,
      'total': total,
      'detail_json': detail == null ? null : jsonEncode(detail),
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> listAll({String? kind}) async {
    final db = await _db;
    return db.query(
      'quality_surveys',
      where: kind == null ? null : 'kind = ?',
      whereArgs: kind == null ? null : [kind],
      orderBy: 'date DESC, created_at DESC',
    );
  }
}

/// 服药打卡：按药 + 日期 + 时间点（早/午/晚）
class MedicationCheckinRepository {
  Future<Database> get _db => LocalDb.instance.database;

  Future<void> markTaken({
    required String medicationId,
    required String date,
    required String slot,
  }) async {
    final db = await _db;
    await db.insert(
      'medication_checkins',
      {
        'id': const Uuid().v4(),
        'medication_id': medicationId,
        'date': date,
        'slot': slot,
        'taken_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> unmark({
    required String medicationId,
    required String date,
    required String slot,
  }) async {
    final db = await _db;
    await db.delete(
      'medication_checkins',
      where: 'medication_id = ? AND date = ? AND slot = ?',
      whereArgs: [medicationId, date, slot],
    );
  }

  /// 某日所有打卡（slot 集合）
  Future<Set<String>> slotsForDate(String medicationId, String date) async {
    final db = await _db;
    final rows = await db.query(
      'medication_checkins',
      where: 'medication_id = ? AND date = ?',
      whereArgs: [medicationId, date],
    );
    return rows.map((r) => '${r['slot']}').toSet();
  }

  /// 日历着色：该月每日打卡次数
  Future<Map<String, int>> takenCountByDate({int days = 60}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT date, COUNT(*) AS c FROM medication_checkins
      GROUP BY date ORDER BY date DESC LIMIT ?
    ''', [days]);
    final out = <String, int>{};
    for (final r in rows) {
      out['${r['date']}'] = (r['c'] as num).toInt();
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> listForDate(String date) async {
    final db = await _db;
    return db.query(
      'medication_checkins',
      where: 'date = ?',
      whereArgs: [date],
    );
  }
}
