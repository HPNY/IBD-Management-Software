import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 端上 Skill 缓存：确认解析后，下次同院同类型可本地快速匹配提示。
class LocalSkillStore {
  static const _kPrefix = 'ibd_skill_v1_';

  static String key(String hospital, String reportType) =>
      '$_kPrefix${hospital}__${reportType}';

  static Future<void> saveFromConfirmed({
    required String hospital,
    required String reportType,
    required List<Map<String, dynamic>> items,
    String? date,
  }) async {
    if (hospital.isEmpty || reportType.isEmpty || items.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final rules = items.map((it) {
      final name = '${it['nameNorm'] ?? it['name'] ?? ''}'.trim();
      final escaped = RegExp.escape(name);
      return {
        'name': name,
        'nameRaw': it['nameRaw'] ?? it['name'],
        'pattern': '$escaped\\s+([\\d.]+)',
        'unit': it['unit'],
        'refMin': it['refMin'] ?? it['ref_min'],
        'refMax': it['refMax'] ?? it['ref_max'],
      };
    }).toList();

    final content = {
      'hospital': hospital,
      'report_type': reportType,
      'savedAt': DateTime.now().toIso8601String(),
      'date': date,
      'items': rules,
    };
    final existing = await sp.getString(key(hospital, reportType));
    var version = 1;
    if (existing != null) {
      try {
        final old = jsonDecode(existing) as Map<String, dynamic>;
        version = ((old['version'] as num?) ?? 0).toInt() + 1;
      } catch (_) {}
    }
    content['version'] = version;
    await sp.setString(key(hospital, reportType), jsonEncode(content));
  }

  static Future<Map<String, dynamic>?> load(
    String hospital,
    String reportType,
  ) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(key(hospital, reportType));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<int> count() async {
    final sp = await SharedPreferences.getInstance();
    return sp
        .getKeys()
        .where((k) => k.startsWith(_kPrefix))
        .length;
  }
}
