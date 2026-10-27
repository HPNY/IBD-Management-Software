import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 端上 Skill 缓存：确认解析后，下次同院同类型可本地快速匹配提示。
///
/// T3：可读（load 接入 txt 快速通道）、可清理（clear/clearAll）、
/// 可失效（formatVersion 不识别或损坏 JSON 一律视为无缓存，安全回落云端）。
class LocalSkillStore {
  static const _kPrefix = 'ibd_skill_v1_';

  /// 缓存内容格式版本；不识别的版本 load() 返回 null（失效）。
  static const formatVersion = 1;

  static String key(String hospital, String reportType) =>
      '$_kPrefix${hospital}__$reportType';

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
      'formatVersion': formatVersion,
      'savedAt': DateTime.now().toIso8601String(),
      'date': date,
      'items': rules,
    };
    final existing = sp.getString(key(hospital, reportType));
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
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      // 失效逻辑：格式不识别（含 T3 之前无 formatVersion 的旧缓存）→ 视为无缓存
      if (decoded['formatVersion'] != formatVersion) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// 清理单个医院/报告类型的缓存。
  static Future<void> clear(String hospital, String reportType) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(key(hospital, reportType));
  }

  /// 清理全部本地 Skill 缓存。
  static Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    for (final k in sp.getKeys().where((k) => k.startsWith(_kPrefix))) {
      await sp.remove(k);
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
