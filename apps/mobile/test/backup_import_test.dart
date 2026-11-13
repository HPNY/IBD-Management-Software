import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/backup/backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_db.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await openTestDb('ibders_backup_import');
  });

  tearDown(() async {
    await db.close();
  });

  test('H1/H19：备份恢复同构且幂等（含检查/手术/打卡）', () async {
    final backup = BackupService('test-user', database: db);
    final payload = {
      'format': 'ibders.backup.v2',
      'labs': [
        {
          'id': 'lab-1',
          'date': '2026-03-01',
          'hospital': '三甲医院A',
          'source': 'manual',
          'created_at': '2026-03-01T10:00:00Z',
          'items': [
            {
              'id': 'item-1',
              'name_norm': '白蛋白',
              'name_raw': 'ALB',
              'value': 45,
              'unit': 'g/L',
            },
          ],
        },
      ],
      'medications': [
        {
          'id': 'med-1',
          'drug_name': '美沙拉秦',
          'dosage': '1g',
          'frequency': 'bid',
          'route': 'oral',
          'start_date': '2026-01-01',
          'status': 'active',
        },
      ],
      'medicationCheckins': [
        {
          'id': 'ck-1',
          'medication_id': 'med-1',
          'date': '2026-03-01',
          'slot': 'am',
          'created_at': '2026-03-01T08:00:00Z',
        },
      ],
      'symptoms': [
        {'id': 'sym-1', 'date': '2026-03-01', 'pain_level': 2},
      ],
      'exams': [
        {
          'id': 'exam-1',
          'date': '2026-02-01',
          'type': '肠镜',
          'findings': '轻度活动',
        },
      ],
      'surgeries': [
        {
          'id': 'surg-1',
          'date': '2020-05-01',
          'type': '回盲部切除',
        },
      ],
    };

    final first = await backup.importFromJsonString(
      jsonEncode(payload),
    );
    expect(first, greaterThan(0));

    final second = await backup.importFromJsonString(
      jsonEncode(payload),
    );
    expect(second, 0, reason: '重复恢复必须全部跳过');

    expect((await db.query('labs')), hasLength(1));
    expect((await db.query('lab_items')), hasLength(1));
    expect((await db.query('medications')), hasLength(1));
    expect((await db.query('medication_checkins')), hasLength(1));
    expect((await db.query('symptom_diaries')), hasLength(1));
    expect((await db.query('exams')), hasLength(1));
    expect((await db.query('surgeries')), hasLength(1));
  });
}
