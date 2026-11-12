import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/db/local_db.dart';

void main() {
  test('C2：迁移后不保留明文全库副本，且清理幂等', () async {
    final dir = await Directory.systemTemp.createTemp('ibders_plain_bak');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final dbPath = '${dir.path}/ibders_local.db';
    final bak = File('$dbPath.plain.bak');
    await bak.writeAsString('SQLite format 3 plaintext medical data');

    await LocalDb.deleteLegacyPlainBackup(dbPath);
    expect(await bak.exists(), isFalse, reason: '残留明文副本必须删除');

    // 幂等：不存在时再次调用不抛错
    await LocalDb.deleteLegacyPlainBackup(dbPath);
    expect(await bak.exists(), isFalse);
  });
}
