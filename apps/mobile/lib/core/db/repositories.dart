import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../lab/lab_panels.dart';
import 'local_db.dart';

class LabRepository {
  /// 测试可注入 Database，生产走 LocalDb。
  LabRepository({Database? database}) : _dbOverride = database;

  final Database? _dbOverride;
  Future<Database> get _db async =>
      _dbOverride ?? await LocalDb.instance.database;

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
          // 兼容 camelCase（录入）与 snake_case（备份回写）
          'name_norm': it['nameNorm'] ?? it['name_norm'] ?? it['name'] ?? '',
          'name_raw': it['nameRaw'] ??
              it['name_raw'] ??
              it['name_norm'] ??
              it['name'] ??
              '',
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

  /// P0-4：编辑检验记录的日期/医院（错录可就地修正）。
  Future<void> updateMeta(
    String labId, {
    required String date,
    String? hospital,
  }) async {
    final db = await _db;
    await db.update(
      'labs',
      {'date': date, 'hospital': hospital},
      where: 'id = ?',
      whereArgs: [labId],
    );
  }

  /// P0-4：删除整份检验记录（lab_items 由外键级联删除）。
  Future<void> delete(String labId) async {
    final db = await _db;
    await db.delete('labs', where: 'id = ?', whereArgs: [labId]);
  }

  /// P0-4：同日同院、指标与数值完全相同的记录视为重复，返回可合并的组。
  Future<List<List<Map<String, dynamic>>>> duplicateGroups() async {
    final all = await listAll();
    final byKey = <String, List<Map<String, dynamic>>>{};
    for (final lab in all) {
      final items = (lab['items'] as List).cast<Map<String, dynamic>>();
      final sig = items
          .map((i) =>
              '${i['name_norm']}:${i['value']}:${i['unit'] ?? ''}')
          .toList()
        ..sort();
      final key = '${lab['date']}|${lab['hospital'] ?? ''}|${sig.join(',')}';
      byKey.putIfAbsent(key, () => []).add(lab);
    }
    return byKey.values.where((g) => g.length > 1).toList();
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
  /// 测试可注入 Database，生产走 LocalDb。
  SymptomRepository({Database? database}) : _dbOverride = database;

  final Database? _dbOverride;
  Future<Database> get _db async =>
      _dbOverride ?? await LocalDb.instance.database;

  /// none/trace/obvious → 排便表 blood 标志（0/1/2）。
  static int? bloodToBathroomFlag(String? bloodyStool) {
    switch (bloodyStool) {
      case 'none':
        return 0;
      case 'trace':
        return 1;
      case 'obvious':
        return 2;
      default:
        return null;
    }
  }

  /// 保存打卡。P0-3：**不再自动生成排便细表记录**——
  /// 打卡与细表是两套录入，自动同步会造成双份记录、两套便血档位。
  /// 历史 `source=checkin` 行在同一日期保存时清理，数据仍保留在本表。
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
    bool? urgency,
    bool? mucus,
    int? bowelCount,
    // G2：日记补全
    bool? oralUlcer,
    bool? jointPain,
    String? jointPainSite,
    String? customItemsJson,
    // G4：睡眠/压力
    double? sleepHours,
    int? sleepQuality,
    bool? sleepInsomnia,
    int? nightWakes,
    int? stressLevel,
    String? stressSource,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      // data_flags 随 replace 语义保留：未提供新腹胀值时沿用旧标记，
      // 提供真实腹胀值（T1 修复后的新数据）则解除 bloating 修复标记。
      final existingRows = await txn.query(
        'symptom_diaries',
        where: 'date = ?',
        whereArgs: [date],
        limit: 1,
      );
      var dataFlags = existingRows.isEmpty
          ? 0
          : ((existingRows.first['data_flags'] as num?) ?? 0).toInt();
      if (bloating != null) {
        dataFlags &= ~kDataFlagBloatingReset;
      }

      await txn.insert(
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
          'data_flags': dataFlags,
          'nausea': nausea == null ? null : (nausea ? 1 : 0),
          'overall_feeling': overallFeeling,
          'urgency': urgency == null ? null : (urgency ? 1 : 0),
          'mucus': mucus == null ? null : (mucus ? 1 : 0),
          'bowel_count': bowelCount,
          'oral_ulcer': oralUlcer == null ? null : (oralUlcer ? 1 : 0),
          'joint_pain': jointPain == null ? null : (jointPain ? 1 : 0),
          'joint_pain_site': jointPainSite,
          'custom_items': customItemsJson,
          'sleep_hours': sleepHours,
          'sleep_quality': sleepQuality,
          'sleep_insomnia':
              sleepInsomnia == null ? null : (sleepInsomnia ? 1 : 0),
          'night_wakes': nightWakes,
          'stress_level': stressLevel,
          'stress_source': stressSource,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // P0-3：清理历史自动同步行（仅当日），不再写入新行。
      await txn.delete(
        'bathroom_records',
        where: "date = ? AND source = 'checkin'",
        whereArgs: [date],
      );
    });
  }

  Future<Map<String, dynamic>?> getByDate(String date) async {
    final db = await _db;
    final rows = await db.query(
      'symptom_diaries',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final db = await _db;
    return db.query('symptom_diaries', orderBy: 'date DESC');
  }
}

class BathroomRepository {
  BathroomRepository({Database? database}) : _dbOverride = database;

  final Database? _dbOverride;
  Future<Database> get _db async =>
      _dbOverride ?? await LocalDb.instance.database;

  Future<void> insert({
    required String date,
    String? time,
    int? stoolType,
    bool? urgency,
    bool? blood,
    bool? mucus,
    String? notes,
    int? dailyCount,
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
      'source': 'manual',
      'daily_count': dailyCount,
    });
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final db = await _db;
    return db.query('bathroom_records', orderBy: 'date DESC, time DESC');
  }

  Future<List<Map<String, dynamic>>> listByDate(String date) async {
    final db = await _db;
    return db.query(
      'bathroom_records',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'time DESC',
    );
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
  LabSeriesRepository({Database? database}) : _dbOverride = database;

  final Database? _dbOverride;
  Future<Database> get _db async =>
      _dbOverride ?? await LocalDb.instance.database;

  /// 按规范名提取时间序列，如 CRP / 钙卫蛋白。
  ///
  /// H17：必须精确匹配 `name_norm`。此前用 `LIKE '%白蛋白%'` 会把
  /// 「前白蛋白」混进白蛋白趋势（量级差 5–10 倍），医生摘要与活动度卡同受影响。
  Future<List<Map<String, dynamic>>> seriesByName(String nameNorm) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT labs.date AS date, lab_items.value AS value, lab_items.unit AS unit
      FROM lab_items
      INNER JOIN labs ON labs.id = lab_items.lab_id
      WHERE lab_items.name_norm = ?
      ORDER BY labs.date ASC
      ''',
      [nameNorm],
    );
    return rows;
  }

  /// 汇总：最近一次各核心指标
  Future<Map<String, Map<String, dynamic>>> latestCore() async {
    final out = <String, Map<String, dynamic>>{};
    for (final n in kCoreLabNames) {
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

/// G6：食物标签日志（本地 v7 food_logs）。
class FoodRepository {
  FoodRepository({Database? database}) : _dbOverride = database;

  final Database? _dbOverride;
  Future<Database> get _db async =>
      _dbOverride ?? await LocalDb.instance.database;

  Future<String> insert({
    required String date,
    required String foods,
    String? meal,
    double? calories,
    double? proteinG,
  }) async {
    final db = await _db;
    final id = const Uuid().v4();
    await db.insert('food_logs', {
      'id': id,
      'date': date,
      'meal': meal,
      'foods': foods,
      'calories': calories,
      'protein_g': proteinG,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final db = await _db;
    return db.query('food_logs', orderBy: 'date DESC, created_at DESC');
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('food_logs', where: 'id = ?', whereArgs: [id]);
  }
}

/// D2：药物评价（本地表 drug_reviews，可匿名上传）。
class DrugReviewRepository {
  DrugReviewRepository({Database? database}) : _dbOverride = database;

  final Database? _dbOverride;
  Future<Database> get _db async =>
      _dbOverride ?? await LocalDb.instance.database;

  Future<String> insert({
    required String drugName,
    required int efficacy,
    required int seSideEffect,
    String? ibdType,
    String? sideEffectTypes,
    bool? stillUsing,
    String? comment,
  }) async {
    final db = await _db;
    final id = const Uuid().v4();
    await db.insert('drug_reviews', {
      'id': id,
      'drug_name': drugName,
      'ibd_type': ibdType,
      'efficacy': efficacy,
      'se_side_effect': seSideEffect,
      'side_effect_types': sideEffectTypes,
      'still_using': stillUsing == null ? null : (stillUsing ? 1 : 0),
      'comment': comment,
      'uploaded': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final db = await _db;
    return db.query('drug_reviews', orderBy: 'created_at DESC');
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('drug_reviews', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markUploaded(String id) async {
    final db = await _db;
    await db.update(
      'drug_reviews',
      {'uploaded': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

/// 生活质量/心理量表（本地，v3）
class QualitySurveyRepository {
  QualitySurveyRepository({Database? database}) : _dbOverride = database;

  final Database? _dbOverride;
  Future<Database> get _db async =>
      _dbOverride ?? await LocalDb.instance.database;

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
