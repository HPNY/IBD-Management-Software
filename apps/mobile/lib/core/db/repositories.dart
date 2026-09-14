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
    final db = await _db;
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
