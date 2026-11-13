import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/local_db.dart';
import '../db/repositories.dart';
import '../skill/local_skill_store.dart';
import 'backup_crypto.dart';

/// 本地导出/导入 + 可选云密文快照。
///
/// H1/H19/A2-O-13：导出与恢复必须**同构**——导出什么就能恢复什么；
/// 检查/手术/用药打卡/副作用/症状/排便/量表/饮食/药评全部纳入。
/// 恢复按主键（症状按日期、打卡按唯一键）幂等，重复恢复不翻倍。
class BackupService {
  BackupService(this.appUserId, {Database? database}) : _dbOverride = database;

  final String appUserId;
  final Database? _dbOverride;

  Future<Database> get _db async =>
      _dbOverride ?? await LocalDb.instance.database;
  static const _kPass = 'ibd_backup_passphrase_v2';
  static const _legacyPass = 'ibd_backup_passphrase';
  static const _format = 'ibders.backup.v2';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final labs = LabRepository();
  final meds = MedicationRepository();
  final injections = InjectionRepository();
  final symptoms = SymptomRepository();
  final bathroom = BathroomRepository();
  final surveys = QualitySurveyRepository();
  final food = FoodRepository();
  final drugReviews = DrugReviewRepository();
  final exams = ExamRepository();
  final surgeries = SurgeryRepository();

  Future<void> savePassphrase(String pass) async {
    await _storage.write(key: _kPass, value: pass);
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_legacyPass);
  }

  Future<String?> loadPassphrase() async {
    final secure = await _storage.read(key: _kPass);
    if (secure != null && secure.isNotEmpty) return secure;
    // 迁移旧明文并删除
    final sp = await SharedPreferences.getInstance();
    final legacy = sp.getString(_legacyPass);
    if (legacy != null && legacy.isNotEmpty) {
      await _storage.write(key: _kPass, value: legacy);
      await sp.remove(_legacyPass);
      return legacy;
    }
    return null;
  }

  Future<Map<String, dynamic>> exportAll() async {
    final db = await _db;
    final skillCount = await LocalSkillStore.count();
    return {
      'format': _format,
      'schemaVersion': 2,
      'appUserId': appUserId,
      'exportedAt': DateTime.now().toIso8601String(),
      'labs': await labs.listAll(),
      'medications': await meds.listAll(),
      'adverseEvents': await db.query('adverse_events'),
      'injections': await injections.listAll(),
      'medicationCheckins': await db.query('medication_checkins'),
      'symptoms': await symptoms.listAll(),
      'bathroom': await bathroom.listAll(),
      'surveys': await surveys.listAll(),
      'exams': await exams.listAll(),
      'surgeries': await surgeries.listAll(),
      'foodLogs': await food.listAll(),
      'drugReviews': await drugReviews.listAll(),
      'localSkillCount': skillCount,
    };
  }

  Future<String> exportToFile() async {
    final data = await exportAll();
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${dir.path}/ibders_backup_$ts.json');
    await file.writeAsString(jsonEncode(data), flush: true);
    return file.path;
  }

  /// 幂等导入：已存在的记录跳过，返回实际新增条数。
  Future<int> importFromJsonString(String raw) async {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final format = data['format'];
    if (format != _format && format != 'ibders.backup.v1') {
      throw Exception('unsupported backup format: $format');
    }
    final db = await _db;
    var restored = 0;

    await db.transaction((txn) async {
      // 1) 检验：labs + lab_items（父子表，先父后子）
      for (final lab in _rows(data['labs'])) {
        final id = _str(lab['id']) ?? const Uuid().v4();
        if (!await _exists(txn, 'labs', id)) {
          await txn.insert('labs', {
            'id': id,
            'date': _str(lab['date']) ?? _today(),
            'hospital': _str(lab['hospital']),
            'source': _str(lab['source']) ?? 'import',
            'created_at':
                _str(lab['created_at']) ?? DateTime.now().toIso8601String(),
          });
          restored++;
        }
        for (final it in _rows(lab['items'])) {
          final itemId = _str(it['id']) ?? const Uuid().v4();
          if (await _exists(txn, 'lab_items', itemId)) continue;
          await txn.insert('lab_items', {
            'id': itemId,
            'lab_id': id,
            'name_norm': _str(it['name_norm'] ?? it['nameNorm'] ?? it['name']) ?? '',
            'name_raw': _str(it['name_raw'] ?? it['nameRaw']) ??
                _str(it['name_norm'] ?? it['name']) ??
                '',
            'value': it['value'],
            'unit': _str(it['unit']),
            'ref_min': it['ref_min'] ?? it['refMin'],
            'ref_max': it['ref_max'] ?? it['refMax'],
            'flag': _str(it['flag']),
          });
          restored++;
        }
      }

      // 2) 用药 + 副作用
      for (final m in _rows(data['medications'])) {
        final id = _str(m['id']) ?? const Uuid().v4();
        if (!await _exists(txn, 'medications', id)) {
          await txn.insert('medications', {
            'id': id,
            'drug_name': _str(m['drug_name'] ?? m['drugName']) ?? '',
            'brand_name': _str(m['brand_name'] ?? m['brandName']),
            'category': _str(m['category']),
            'dosage': _str(m['dosage']) ?? '',
            'frequency': _str(m['frequency']) ?? '',
            'route': _str(m['route']) ?? 'oral',
            'start_date': _str(m['start_date'] ?? m['startDate']) ?? _today(),
            'end_date': _str(m['end_date'] ?? m['endDate']),
            'status': _str(m['status']) ?? 'active',
            'reason': _str(m['reason']),
          });
          restored++;
        }
      }
      for (final e in _rows(data['adverseEvents'])) {
        final id = _str(e['id']) ?? const Uuid().v4();
        if (await _exists(txn, 'adverse_events', id)) continue;
        final medId = _str(e['medication_id'] ?? e['medicationId']);
        if (medId == null || !await _exists(txn, 'medications', medId)) continue;
        await txn.insert('adverse_events', {
          'id': id,
          'medication_id': medId,
          'title': _str(e['title']) ?? '',
          'severity': _str(e['severity']) ?? 'mild',
          'occurred_at': _str(e['occurred_at'] ?? e['occurredAt']) ?? _today(),
          'notes': _str(e['notes']),
        });
        restored++;
      }

      // 3) 注射
      for (final j in _rows(data['injections'])) {
        final id = _str(j['id']) ?? const Uuid().v4();
        if (await _exists(txn, 'injections', id)) continue;
        await txn.insert('injections', {
          'id': id,
          'drug': _str(j['drug'] ?? j['drug_name']) ?? '',
          'planned_date': _str(j['planned_date'] ?? j['plannedDate']) ?? _today(),
          'actual_date': _str(j['actual_date'] ?? j['actualDate']),
          'phase': _str(j['phase']) ?? 'maintenance',
          'dose': _str(j['dose']) ?? '',
          'route': _str(j['route']) ?? 'sc',
          'week_number': j['week_number'] ?? j['weekNumber'] ?? 0,
          'notes': _str(j['notes']),
        });
        restored++;
      }

      // 4) 用药打卡（唯一键 medication_id+date+slot）
      for (final c in _rows(data['medicationCheckins'])) {
        final medId = _str(c['medication_id'] ?? c['medicationId']);
        final date = _str(c['date']);
        final slot = _str(c['slot']);
        if (medId == null || date == null || slot == null) continue;
        final dup = await txn.query(
          'medication_checkins',
          where: 'medication_id = ? AND date = ? AND slot = ?',
          whereArgs: [medId, date, slot],
          limit: 1,
        );
        if (dup.isNotEmpty) continue;
        await txn.insert('medication_checkins', {
          'id': _str(c['id']) ?? const Uuid().v4(),
          'medication_id': medId,
          'date': date,
          'slot': slot,
          'taken_at': _str(c['taken_at'] ?? c['takenAt']),
          'created_at':
              _str(c['created_at']) ?? DateTime.now().toIso8601String(),
        });
        restored++;
      }

      // 5) 症状日记（date UNIQUE）
      for (final s in _rows(data['symptoms'])) {
        final date = _str(s['date']);
        if (date == null) continue;
        final dup = await txn.query(
          'symptom_diaries',
          where: 'date = ?',
          whereArgs: [date],
          limit: 1,
        );
        if (dup.isNotEmpty) continue;
        await txn.insert('symptom_diaries', {
          'id': _str(s['id']) ?? const Uuid().v4(),
          'date': date,
          'pain_level': s['pain_level'] ?? s['painLevel'],
          'diarrhea_count': s['diarrhea_count'] ?? s['diarrheaCount'],
          'stool_type': s['stool_type'] ?? s['stoolType'],
          'bloody_stool': _str(s['bloody_stool'] ?? s['bloodyStool']),
          'bloating': s['bloating'],
          'fatigue': s['fatigue'],
          'data_flags': s['data_flags'] ?? 0,
          'nausea': _boolInt(s['nausea']),
          'overall_feeling': _str(s['overall_feeling'] ?? s['overallFeeling']),
          'urgency': _boolInt(s['urgency']),
          'mucus': _boolInt(s['mucus']),
          'bowel_count': s['bowel_count'] ?? s['bowelCount'],
          'oral_ulcer': _boolInt(s['oral_ulcer'] ?? s['oralUlcer']),
          'joint_pain': _boolInt(s['joint_pain'] ?? s['jointPain']),
          'joint_pain_site': _str(s['joint_pain_site'] ?? s['jointPainSite']),
          'custom_items': _str(s['custom_items'] ?? s['customItems']),
          'sleep_hours': s['sleep_hours'] ?? s['sleepHours'],
          'sleep_quality': s['sleep_quality'] ?? s['sleepQuality'],
          'sleep_insomnia': _boolInt(s['sleep_insomnia'] ?? s['sleepInsomnia']),
          'night_wakes': s['night_wakes'] ?? s['nightWakes'],
          'stress_level': s['stress_level'] ?? s['stressLevel'],
          'stress_source': _str(s['stress_source'] ?? s['stressSource']),
        });
        restored++;
      }

      // 6) 排便细表
      for (final b in _rows(data['bathroom'])) {
        final id = _str(b['id']) ?? const Uuid().v4();
        if (await _exists(txn, 'bathroom_records', id)) continue;
        await txn.insert('bathroom_records', {
          'id': id,
          'date': _str(b['date']) ?? _today(),
          'time': _str(b['time']),
          'stool_type': b['stool_type'] ?? b['stoolType'],
          'urgency': b['urgency'],
          'blood': b['blood'],
          'mucus': b['mucus'],
          'source': _str(b['source']) ?? 'import',
          'daily_count': b['daily_count'] ?? b['dailyCount'],
          'diarrhea_count': b['diarrhea_count'] ?? b['diarrheaCount'],
          'notes': _str(b['notes']),
        });
        restored++;
      }

      // 7) 量表
      for (final q in _rows(data['surveys'])) {
        final id = _str(q['id']) ?? const Uuid().v4();
        if (await _exists(txn, 'quality_surveys', id)) continue;
        await txn.insert('quality_surveys', {
          'id': id,
          'date': _str(q['date']) ?? _today(),
          'kind': _str(q['kind']) ?? 'IBDQ',
          'total': q['total'] ?? 0,
          'detail_json': _str(q['detail_json'] ?? q['detailJson']),
          'created_at':
              _str(q['created_at']) ?? DateTime.now().toIso8601String(),
        });
        restored++;
      }

      // 8) 检查 / 手术（A2-O-13：此前从未进入备份）
      for (final e in _rows(data['exams'])) {
        final id = _str(e['id']) ?? const Uuid().v4();
        if (await _exists(txn, 'exams', id)) continue;
        await txn.insert('exams', {
          'id': id,
          'date': _str(e['date']) ?? _today(),
          'type': _str(e['type']) ?? '',
          'body_part': _str(e['body_part'] ?? e['bodyPart']),
          'findings': _str(e['findings']),
          'diagnosis': _str(e['diagnosis']),
          'score': _str(e['score']),
          'comparison': _str(e['comparison']),
          'created_at':
              _str(e['created_at']) ?? DateTime.now().toIso8601String(),
        });
        restored++;
      }
      for (final s in _rows(data['surgeries'])) {
        final id = _str(s['id']) ?? const Uuid().v4();
        if (await _exists(txn, 'surgeries', id)) continue;
        await txn.insert('surgeries', {
          'id': id,
          'date': _str(s['date']) ?? _today(),
          'type': _str(s['type']),
          'body_part': _str(s['body_part'] ?? s['bodyPart']),
          'findings': _str(s['findings']),
          'procedure': _str(s['procedure']),
          'resected_length_cm':
              s['resected_length_cm'] ?? s['resectedLengthCm'],
          'anastomosis': _str(s['anastomosis']),
          'surgeon': _str(s['surgeon']),
          'notes': _str(s['notes']),
        });
        restored++;
      }

      // 9) 饮食 / 药物评价
      for (final f in _rows(data['foodLogs'])) {
        final id = _str(f['id']) ?? const Uuid().v4();
        if (await _exists(txn, 'food_logs', id)) continue;
        await txn.insert('food_logs', {
          'id': id,
          'date': _str(f['date']) ?? _today(),
          'meal': _str(f['meal']),
          'foods': _str(f['foods']) ?? '',
          'created_at': _str(f['created_at']),
          'calories': f['calories'],
          'protein_g': f['protein_g'] ?? f['proteinG'],
        });
        restored++;
      }
      for (final d in _rows(data['drugReviews'])) {
        final id = _str(d['id']) ?? const Uuid().v4();
        if (await _exists(txn, 'drug_reviews', id)) continue;
        await txn.insert('drug_reviews', {
          'id': id,
          'drug_name': _str(d['drug_name'] ?? d['drugName']) ?? '',
          'ibd_type': _str(d['ibd_type'] ?? d['ibdType']),
          'efficacy': d['efficacy'] ?? 0,
          'se_side_effect': d['se_side_effect'] ?? d['seSideEffect'] ?? 0,
          'side_effect_types':
              _str(d['side_effect_types'] ?? d['sideEffectTypes']),
          'still_using': _boolInt(d['still_using'] ?? d['stillUsing']),
          'comment': _str(d['comment']),
          'uploaded': d['uploaded'] ?? 0,
          'created_at': _str(d['created_at']),
        });
        restored++;
      }
    });
    return restored;
  }

  Future<Map<String, String>> encryptSnapshot(String passphrase) async {
    final data = await exportAll();
    return BackupCrypto.encryptJson(
      data,
      passphrase: passphrase,
      appUserId: appUserId,
    );
  }

  Future<int> restoreFromCloud({
    required String passphrase,
    required String cipher,
    required String nonce,
    required String mac,
    String? salt,
    /// 换机恢复：旧设备的 appUserId（历史无盐快照仍按它派生）
    String? sourceAppUserId,
  }) async {
    final data = await BackupCrypto.decryptJson(
      cipherB64: cipher,
      nonceB64: nonce,
      macB64: mac,
      passphrase: passphrase,
      appUserId: sourceAppUserId ?? appUserId,
      saltB64: salt,
    );
    return importFromJsonString(jsonEncode(data));
  }

  static List<Map<String, dynamic>> _rows(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  static String? _str(Object? v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static int? _boolInt(Object? v) {
    if (v == null) return null;
    if (v is bool) return v ? 1 : 0;
    if (v is num) return v.toInt();
    return null;
  }

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  static Future<bool> _exists(
    Transaction txn,
    String table,
    String id,
  ) async {
    final rows = await txn.query(
      table,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}

/// 本地敏感文本字段加密（停药原因等）：返回 JSON 包 {cipher,nonce,mac}
Future<String> encryptSensitiveField(
  String plain,
  String passphrase,
  String appUserId,
) async {
  if (plain.isEmpty) return '';
  final box = await BackupCrypto.encryptJson(
    {'v': plain},
    passphrase: passphrase,
    appUserId: appUserId,
  );
  return jsonEncode(box);
}

Future<String> decryptSensitiveField(
  String packed,
  String passphrase,
  String appUserId,
) async {
  if (packed.isEmpty) return '';
  final map = jsonDecode(packed) as Map<String, dynamic>;
  final data = await BackupCrypto.decryptJson(
    cipherB64: map['cipher'] as String,
    nonceB64: map['nonce'] as String,
    macB64: map['mac'] as String,
    passphrase: passphrase,
    appUserId: appUserId,
    saltB64: map['salt'] as String?,
  );
  return data['v'] as String? ?? '';
}
