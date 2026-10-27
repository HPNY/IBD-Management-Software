import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/features/analysis/my_doctors_page.dart';

/// T5：患者侧医生数据接真实 API 的 UI 回归（注入 Fake 数据源）。
class _FakeSource implements DoctorPatientSource {
  _FakeSource({
    this.grants = const [],
    this.notes = const [],
    this.audits = const [],
    this.failLoad = false,
    this.failConfirm = false,
  });

  final List<Map<String, dynamic>> grants;
  final List<Map<String, dynamic>> notes;
  final List<Map<String, dynamic>> audits;
  final bool failLoad;
  final bool failConfirm;
  final List<String> revokedIds = [];
  final List<String> confirmedCodes = [];

  @override
  Future<List<Map<String, dynamic>>> loadGrants() async {
    if (failLoad) throw Exception('offline');
    return grants;
  }

  @override
  Future<List<Map<String, dynamic>>> loadNotes() async {
    if (failLoad) throw Exception('offline');
    return notes;
  }

  @override
  Future<List<Map<String, dynamic>>> loadAudits() async {
    if (failLoad) throw Exception('offline');
    return audits;
  }

  @override
  Future<void> confirm(
    String code, {
    List<String>? scope,
    String? wrappedDek,
  }) async {
    if (failConfirm) throw Exception('offline');
    confirmedCodes.add(code);
  }

  @override
  Future<void> revoke(String grantId) async {
    revokedIds.add(grantId);
  }
}

Future<void> _pump(WidgetTester tester, _FakeSource source) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: MyDoctorsPage(source: source)));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('授权/建议/审计渲染真实 API 数据', (tester) async {
    final source = _FakeSource(
      grants: [
        {
          'id': 'g1',
          'doctorId': 'doc-1',
          'scope': ['labs', 'symptoms'],
          'code': null,
          'expiresAt': '2026-12-01T00:00:00.000',
          'confirmed': true,
        },
      ],
      notes: [
        {'content': '建议下次复查钙卫蛋白', 'createdAt': '2026-10-01T10:00:00.000'},
      ],
      audits: [
        {'action': 'view', 'createdAt': '2026-10-01T10:05:00.000'},
      ],
    );
    await _pump(tester, source);

    expect(find.text('医生 doc-1'), findsOneWidget);
    expect(find.textContaining('范围 labs/symptoms'), findsOneWidget);
    expect(find.text('建议下次复查钙卫蛋白'), findsOneWidget);
    expect(find.text('view'), findsOneWidget);
    // 确认后 code 脱敏，不显示授权码原文（null 也不渲染）
    expect(find.textContaining('授权码 null'), findsNothing);
  });

  testWidgets('空态：无授权/建议/审计', (tester) async {
    await _pump(tester, _FakeSource());
    expect(find.text('暂无授权'), findsOneWidget);
    expect(find.text('暂无建议'), findsOneWidget);
    expect(find.text('暂无审计记录'), findsOneWidget);
  });

  testWidgets('加载失败：错误态 + 重试可用，确认入口保留', (tester) async {
    await _pump(tester, _FakeSource(failLoad: true));
    expect(find.textContaining('加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('确认授权'), findsOneWidget);
  });

  testWidgets('收回授权传 grantId（非 code）', (tester) async {
    final source = _FakeSource(
      grants: [
        {
          'id': 'grant-abc',
          'doctorId': 'doc-2',
          'scope': ['labs'],
          'code': null,
          'expiresAt': '2026-12-01T00:00:00.000',
          'confirmed': true,
        },
      ],
    );
    await _pump(tester, source);

    await tester.ensureVisible(find.text('收回'));
    await tester.tap(find.text('收回'));
    await tester.pump();
    await tester.pump();

    expect(source.revokedIds, ['grant-abc']);
    expect(find.text('已收回授权'), findsOneWidget);
  });

  testWidgets('确认失败降级为本地未同步（不伪称已确认）', (tester) async {
    final source = _FakeSource(failConfirm: true);
    await _pump(tester, source);

    await tester.enterText(find.byType(TextField).first, 'abc123');
    await tester.pump();
    await tester.ensureVisible(find.text('确认授权'));
    await tester.tap(find.text('确认授权'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('本地未同步'), findsOneWidget);
    expect(find.textContaining('未同步到服务端'), findsOneWidget);
    expect(source.confirmedCodes, isEmpty);
  });
}
