import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/repositories.dart';
import 'backup_crypto.dart';

/// 本地导出/导入 + 可选云密文快照。
class BackupService {
  BackupService(this.appUserId);

  final String appUserId;
  static const _kPass = 'ibd_backup_passphrase';

  final labs = LabRepository();
  final meds = MedicationRepository();
  final injections = InjectionRepository();
  final symptoms = SymptomRepository();

  Future<void> savePassphrase(String pass) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPass, pass);
  }

  Future<String?> loadPassphrase() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kPass);
  }

  Future<Map<String, dynamic>> exportAll() async {
    return {
      'format': 'ibders.backup.v1',
      'appUserId': appUserId,
      'exportedAt': DateTime.now().toIso8601String(),
      'labs': await labs.listAll(),
      'medications': await meds.listAll(),
      'adverseEvents': <Map<String, dynamic>>[],
      'injections': await injections.listAll(),
      'symptoms': await symptoms.listAll(),
    };
  }

  /// 导出到应用文档目录，返回文件路径。
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

  /// 从本地备份 JSON 导入（用户自选文件内容）。
  Future<void> importFromJsonString(String raw) async {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['format'] != 'ibders.backup.v1') {
      throw Exception('unsupported backup format');
    }
    final labList = (data['labs'] as List?) ?? [];
    for (final lab in labList) {
      final m = Map<String, dynamic>.from(lab as Map);
      await labs.insert(
        date: m['date'] as String? ?? DateTime.now().toIso8601String().substring(0, 10),
        hospital: m['hospital'] as String?,
        source: (m['source'] as String?) ?? 'import',
        items: ((m['items'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
    }
    final medList = (data['medications'] as List?) ?? [];
    for (final med in medList) {
      final m = Map<String, dynamic>.from(med as Map);
      await meds.insert({
        'drugName': m['drug_name'] ?? m['drugName'],
        'brandName': m['brand_name'] ?? m['brandName'],
        'category': m['category'],
        'dosage': m['dosage'] ?? '',
        'frequency': m['frequency'] ?? '',
        'route': m['route'] ?? 'oral',
        'startDate': m['start_date'] ?? m['startDate'] ?? DateTime.now().toIso8601String().substring(0, 10),
        'status': m['status'] ?? 'active',
        'reason': m['reason'],
      });
    }
    final injList = (data['injections'] as List?) ?? [];
    if (injList.isNotEmpty) {
      await injections.insertMany(
        injList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((m) => {
                  'drug': m['drug'] ?? m['drug_name'],
                  'plannedDate': m['planned_date'] ?? m['plannedDate'],
                  'actualDate': m['actual_date'] ?? m['actualDate'],
                  'phase': m['phase'] ?? 'maintenance',
                  'dose': m['dose'] ?? '',
                  'route': m['route'] ?? 'sc',
                  'weekNumber': m['week_number'] ?? m['weekNumber'] ?? 0,
                  'notes': m['notes'],
                })
            .toList(),
      );
    }
  }

  Future<Map<String, String>> encryptSnapshot(String passphrase) async {
    final data = await exportAll();
    return BackupCrypto.encryptJson(
      data,
      passphrase: passphrase,
      appUserId: appUserId,
    );
  }
}
