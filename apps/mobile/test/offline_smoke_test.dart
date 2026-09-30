import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/db/repositories.dart';
import 'package:ibd_mobile/core/identity/local_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_db_harness.dart';

/// local-first Phase1「无网冒烟」自动化代理：
/// 本地身份、打卡增删改查、历史读取、量表保存均不依赖网络。
/// 真机飞行模式/抓包仍待 T2.4/T2.5 设备验收复验。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LocalIdentity 无网络生成并持久化 app_user_uuid', () async {
    SharedPreferences.setMockInitialValues({});
    final id = LocalIdentity();
    await id.load();
    expect(id.isLoaded, isTrue);
    expect(id.uuid, isNotEmpty);
    final again = LocalIdentity();
    await again.load();
    expect(again.uuid, id.uuid, reason: '同机稳定 uuid，无远程依赖');
  });

  test('打卡写读往返 + 历史列表：本地库闭环', () async {
    final h = await TestDbHarness.open(name: 'offline_smoke');
    addTearDown(h.dispose);

    await h.symptoms.upsert(
      date: '2026-09-01',
      painLevel: 3,
      diarrheaCount: 2,
      overallFeeling: 'same',
      oralUlcer: true,
      sleepHours: 7.5,
      stressLevel: 4,
    );
    final row = await h.symptoms.getByDate('2026-09-01');
    expect(row, isNotNull);
    expect(row!['pain_level'], 3);
    expect(row['oral_ulcer'], 1);
    expect(row['sleep_hours'], 7.5);

    await h.symptoms.upsert(
      date: '2026-09-01',
      painLevel: 1,
      diarrheaCount: 0,
      overallFeeling: 'better',
    );
    final updated = await h.symptoms.getByDate('2026-09-01');
    expect(updated!['pain_level'], 1);
    expect(updated['overall_feeling'], 'better');

    final all = await h.symptoms.listAll();
    expect(all.length, greaterThanOrEqualTo(1));
    expect(all.any((e) => e['date'] == '2026-09-01'), isTrue);
  });

  test('量表保存/读取：本地质量调研闭环（含 domains）', () async {
    final h = await TestDbHarness.open(name: 'offline_qol');
    addTearDown(h.dispose);
    await h.db.execute('''
      CREATE TABLE quality_surveys (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        kind TEXT NOT NULL,
        total INTEGER NOT NULL,
        detail_json TEXT,
        created_at TEXT
      )
    ''');
    final qol = QualitySurveyRepository(database: h.db);
    await qol.save(
      date: '2026-09-02',
      kind: 'SF36',
      total: 120,
      detail: {
        'band': '较好',
        'scoring': 'v1-parallel',
        'domains': {
          'gh': 80,
          'pf': 90,
          'rp': 70,
          'bp': 60,
          'vt': 50,
          'sf': 70,
          're': 75,
          'mh': 65,
        },
        'stdAverage': 70,
      },
    );
    final rows = await qol.listAll(kind: 'SF36');
    expect(rows.length, 1);
    expect(rows.single['detail_json'], contains('stdAverage'));
  });
}
