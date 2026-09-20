import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'db_key_service.dart';

/// 本地权威库（SQLCipher 全库加密）。
/// 密钥在 Keystore/Keychain，不在 SharedPreferences。
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  static const dbFileName = 'ibders_local.db';

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, dbFileName);
    final key = await DbKeyService.instance.getOrCreateKey();
    // SQLCipher 口令：二进制密钥用 x'hex'
    final password = 'x${_toHex(key)}';

    await _migratePlainToCipherIfNeeded(path, password);

    final db = await openDatabase(
      path,
      password: password,
      version: 5,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, v) async {
        await _onCreate(db, v);
        await _onUpgrade(db, 1, v);
      },
      onUpgrade: _onUpgrade,
    );
    _db = db;
    return db;
  }

  static String _toHex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// 旧版本明文库 → SQLCipher：导出到临时加密库再替换文件。
  Future<void> _migratePlainToCipherIfNeeded(
    String path,
    String password,
  ) async {
    final file = File(path);
    if (!await file.exists()) return;

    // 若已是加密库，用密码打开会成功；明文库用密码打开通常失败或 cipher 校验失败。
    // 策略：先尝试空密码打开看是否 SQLITE_NOTADB / 非加密；成功则迁移。
    Database? plain;
    try {
      plain = await openDatabase(path);
    } catch (_) {
      // 已是加密或损坏，走正常加密打开
      return;
    }

    try {
      // 能无密码打开说明是明文库 → ATTACH 加密库并复制
      final tmp = '$path.cipher_mig';
      if (await File(tmp).exists()) await File(tmp).delete();
      await plain.execute("ATTACH DATABASE '$tmp' AS enc KEY '$password'");
      await plain.execute(
        "SELECT sqlcipher_export('enc')",
      );
      await plain.execute('DETACH DATABASE enc');
      await plain.close();
      plain = null;

      // 备份旧库，换成加密库
      final bak = '$path.plain.bak';
      if (await File(bak).exists()) await File(bak).delete();
      await file.copy(bak);
      await File(tmp).rename(path);
    } catch (_) {
      // 迁移失败则保留原库，后续业务层可能报错；不静默删数据
      rethrow;
    } finally {
      if (plain != null && plain.isOpen) {
        await plain.close();
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE labs (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        hospital TEXT,
        source TEXT NOT NULL DEFAULT 'manual',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE lab_items (
        id TEXT PRIMARY KEY,
        lab_id TEXT NOT NULL REFERENCES labs(id) ON DELETE CASCADE,
        name_norm TEXT NOT NULL,
        name_raw TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT,
        ref_min REAL,
        ref_max REAL,
        flag TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE medications (
        id TEXT PRIMARY KEY,
        drug_name TEXT NOT NULL,
        brand_name TEXT,
        category TEXT,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        route TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        reason TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE adverse_events (
        id TEXT PRIMARY KEY,
        medication_id TEXT NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        severity TEXT NOT NULL DEFAULT 'mild',
        occurred_at TEXT NOT NULL,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE injections (
        id TEXT PRIMARY KEY,
        drug TEXT NOT NULL,
        planned_date TEXT NOT NULL,
        actual_date TEXT,
        phase TEXT NOT NULL,
        dose TEXT NOT NULL,
        route TEXT NOT NULL,
        week_number INTEGER NOT NULL,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE symptom_diaries (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        pain_level INTEGER,
        diarrhea_count INTEGER,
        stool_type INTEGER,
        bloody_stool TEXT,
        bloating INTEGER,
        fatigue INTEGER,
        nausea INTEGER,
        overall_feeling TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE parse_jobs (
        id TEXT PRIMARY KEY,
        object_key TEXT,
        hospital_hint TEXT,
        report_type TEXT,
        status TEXT NOT NULL,
        items_json TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// v2：排便细表、检查/手术
  Future<void> _onUpgrade(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bathroom_records (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          time TEXT,
          stool_type INTEGER,
          urgency INTEGER,
          blood INTEGER,
          mucus INTEGER,
          notes TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS exams (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          type TEXT NOT NULL,
          body_part TEXT,
          findings TEXT,
          diagnosis TEXT,
          score TEXT,
          comparison TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS surgeries (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          type TEXT,
          body_part TEXT,
          findings TEXT,
          procedure TEXT,
          resected_length_cm REAL,
          anastomosis TEXT,
          surgeon TEXT,
          notes TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bath_date ON bathroom_records (date)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_exam_date ON exams (date)',
      );
    }
    if (from < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quality_surveys (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          kind TEXT NOT NULL,
          total INTEGER NOT NULL,
          detail_json TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_qol_date ON quality_surveys (date)',
      );
    }
    if (from < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS medication_checkins (
          id TEXT PRIMARY KEY,
          medication_id TEXT NOT NULL,
          date TEXT NOT NULL,
          slot TEXT NOT NULL,
          taken_at TEXT,
          created_at TEXT NOT NULL,
          UNIQUE(medication_id, date, slot)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_med_ck_date ON medication_checkins (date)',
      );
    }
    if (from < 5) {
      // 打卡补齐排便细表字段，避免重复填写
      await db.execute(
        'ALTER TABLE symptom_diaries ADD COLUMN urgency INTEGER',
      );
      await db.execute(
        'ALTER TABLE symptom_diaries ADD COLUMN mucus INTEGER',
      );
      await db.execute(
        'ALTER TABLE symptom_diaries ADD COLUMN bowel_count INTEGER',
      );
      // source: manual=细表手记, checkin=打卡同步；daily_count=当日累计次数
      await db.execute(
        "ALTER TABLE bathroom_records ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'",
      );
      await db.execute(
        'ALTER TABLE bathroom_records ADD COLUMN daily_count INTEGER',
      );
      await db.execute(
        'ALTER TABLE bathroom_records ADD COLUMN diarrhea_count INTEGER',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bath_source ON bathroom_records (source)',
      );
    }
  }

  /// 校验加密库可被当前密钥打开（健康检查用）。
  Future<bool> verifyOpenable() async {
    try {
      final db = await database;
      await db.rawQuery('SELECT count(*) FROM sqlite_master');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// 诊断用：库文件大小与是否加密（cipher_provider 非空）。
  Future<Map<String, Object?>> probe() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, dbFileName);
    final size = await File(path).length().catchError((_) => 0);
    final db = await database;
    final rows = await db.rawQuery('PRAGMA cipher_provider');
    return {
      'path': path,
      'sizeBytes': size,
      'cipherProvider': rows.isEmpty ? null : rows.first.values.first,
      'hasKey': await DbKeyService.instance.hasKey(),
    };
  }
}
