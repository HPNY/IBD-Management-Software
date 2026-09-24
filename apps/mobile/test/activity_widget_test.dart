import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibd_mobile/core/db/repositories.dart';
import 'package:ibd_mobile/core/identity/local_identity.dart';
import 'package:ibd_mobile/core/ui/accessibility.dart';
import 'package:ibd_mobile/core/ui/theme.dart';
import 'package:ibd_mobile/features/home/activity_detail_page.dart';
import 'package:ibd_mobile/features/home/dashboard_tab.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 仓库假件：只覆盖仪表盘/活动度页读取的列表方法，不碰 SQLCipher。
class _FakeInjectionRepo extends InjectionRepository {
  _FakeInjectionRepo(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> listAll() async => rows;

  @override
  Future<List<Map<String, dynamic>>> listPending({int withinDays = 60}) async {
    final now = DateTime.now();
    return rows.where((r) {
      if (r['actual_date'] != null) return false;
      final planned = DateTime.tryParse('${r['planned_date']}');
      if (planned == null) return false;
      return planned.isBefore(now.add(Duration(days: withinDays)));
    }).toList();
  }
}

class _FakeLabRepo extends LabRepository {
  _FakeLabRepo(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> listAll() async => rows;
}

class _FakeMedRepo extends MedicationRepository {
  _FakeMedRepo(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> listCurrent() async => rows;

  @override
  Future<List<Map<String, dynamic>>> listAll() async => rows;
}

class _FakeSymptomRepo extends SymptomRepository {
  _FakeSymptomRepo();
  // 空实现：首页仅检查今日是否有打卡。
  @override
  Future<List<Map<String, dynamic>>> listAll() async => const [];
}

class _FakeExamRepo extends ExamRepository {
  _FakeExamRepo(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> listAll() async => rows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpWithIdentity(WidgetTester tester, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    final identity = LocalIdentity();
    await identity.load();
    final a11y = AccessibilityPrefs();
    await a11y.load();
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LocalIdentity>.value(value: identity),
          ChangeNotifierProvider<AccessibilityPrefs>.value(value: a11y),
        ],
        child: MaterialApp(
          theme: buildIbdTheme(),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('首页疾病活动度卡可渲染', (tester) async {
    final soon = DateTime.now().add(const Duration(days: 2));
    final soonIso =
        '${soon.year.toString().padLeft(4, '0')}-${soon.month.toString().padLeft(2, '0')}-${soon.day.toString().padLeft(2, '0')}';
    await pumpWithIdentity(
      tester,
      DashboardTab(
        onOpen: (_) {},
        injRepo: _FakeInjectionRepo([
          {
            'id': 'i1',
            'drug': 'Skyrizi',
            'planned_date': soonIso,
            'actual_date': null,
            'dose': '150mg',
          },
        ]),
        labRepo: _FakeLabRepo([
          {
            'date': '2026-09-01',
            'items': [
              {'nameNorm': '超敏C反应蛋白', 'value': 8.0, 'flag': 'high'},
            ],
          },
        ]),
        medRepo: _FakeMedRepo([
          {'drugName': '美沙拉嗪', 'dosage': '1g', 'frequency': 'bid', 'status': 'active'},
        ]),
        symptomRepo: _FakeSymptomRepo(),
      ),
    );

    expect(find.text('疾病活动度'), findsOneWidget);
    expect(find.textContaining('注射倒计时'), findsOneWidget);
    expect(find.text('CRP'), findsOneWidget);
    expect(find.textContaining('美沙拉嗪'), findsOneWidget);
  });

  testWidgets('疾病活动度详情页可渲染', (tester) async {
    final soon = DateTime.now().add(const Duration(days: 5));
    final soonIso =
        '${soon.year.toString().padLeft(4, '0')}-${soon.month.toString().padLeft(2, '0')}-${soon.day.toString().padLeft(2, '0')}';
    await pumpWithIdentity(
      tester,
      ActivityDetailPage(
        labRepo: _FakeLabRepo([
          {
            'date': '2026-08-01',
            'items': [
              {'nameNorm': '血沉', 'value': 10.0, 'flag': null, 'unit': 'mm/h'},
            ],
          },
        ]),
        medRepo: _FakeMedRepo([
          {'drugName': '阿达木单抗', 'dosage': '40mg', 'frequency': 'q2w', 'status': 'active'},
        ]),
        injRepo: _FakeInjectionRepo([
          {
            'id': 'i1',
            'drug': 'Skyrizi',
            'planned_date': soonIso,
            'actual_date': null,
            'dose': '150mg',
          },
        ]),
        examRepo: _FakeExamRepo([
          {
            'date': '2026-05-01',
            'type': '超声',
            'score': 'Limberg II',
            'findings': null,
          },
          {
            'date': '2026-04-01',
            'type': '肠镜',
            'score': 'SES-CD 8',
            'findings': null,
          },
        ]),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('疾病活动度'), findsOneWidget);
    expect(find.text('炎症三联状态灯'), findsOneWidget);
    expect(find.text('Limberg 分级趋势（超声）'), findsOneWidget);
    expect(find.text('SES-CD 评分趋势（内镜）'), findsOneWidget);
    expect(find.text('II'), findsWidgets);
    expect(find.text('8'), findsWidgets);
    expect(find.text('当前用药方案'), findsOneWidget);
    expect(find.textContaining('还有'), findsOneWidget);
  });
}
