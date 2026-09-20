import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/features/analysis/clinical_pages.dart';
import 'package:ibd_mobile/features/symptom/symptom_page.dart';

import 'test_db_harness.dart';

/// flutter_test 默认 FakeAsync，sqflite ffi 的真实 I/O 需在 runAsync 中完成。
Future<void> flushDb(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> pumpSymptom(WidgetTester tester, TestDbHarness harness) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SymptomPage(
        embedded: true,
        symptomRepo: harness.symptoms,
        bathroomRepo: harness.bathroom,
      ),
    ),
  );
  await flushDb(tester);
}

Future<void> pumpBathroom(WidgetTester tester, TestDbHarness harness) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BathroomPage(repo: harness.bathroom),
    ),
  );
  await flushDb(tester);
}

Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();
  await flushDb(tester);
}

String todayIso() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}
