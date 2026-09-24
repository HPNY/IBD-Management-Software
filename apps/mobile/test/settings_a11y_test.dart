import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ibd_mobile/core/api/api_config.dart';
import 'package:ibd_mobile/core/auth/auth_session.dart';
import 'package:ibd_mobile/core/auth/token_store.dart';
import 'package:ibd_mobile/core/diagnostics/diagnostics_prefs.dart';
import 'package:ibd_mobile/core/i18n/app_locale.dart';
import 'package:ibd_mobile/core/identity/local_identity.dart';
import 'package:ibd_mobile/core/ui/accessibility.dart';
import 'package:ibd_mobile/features/settings/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('设置页展示大字体/简洁/语言/诊断开关', (tester) async {
    final identity = LocalIdentity();
    await identity.load();
    final auth = AuthSession(ApiConfig.dev(), TokenStore());
    final a11y = AccessibilityPrefs();
    await a11y.load();
    final locale = AppLocale();
    await locale.load();
    final diag = DiagnosticsPrefs();
    await diag.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LocalIdentity>.value(value: identity),
          ChangeNotifierProvider<AuthSession>.value(value: auth),
          ChangeNotifierProvider<AccessibilityPrefs>.value(value: a11y),
          ChangeNotifierProvider<AppLocale>.value(value: locale),
          ChangeNotifierProvider<DiagnosticsPrefs>.value(value: diag),
        ],
        child: const MaterialApp(home: SettingsPage(embedded: true)),
      ),
    );
    // SettingsPage 有异步初始化，不用 pumpAndSettle（会挂起）
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // 列表下方内容可能 offstage，全树查找
    expect(find.text('大字体模式', skipOffstage: false), findsWidgets);
    expect(find.text('简洁模式', skipOffstage: false), findsWidgets);
    expect(find.text('中文', skipOffstage: false), findsWidgets);
    expect(find.text('English', skipOffstage: false), findsWidgets);
    expect(find.text('允许匿名诊断上报', skipOffstage: false), findsWidgets);

    // 卸载，避免 pending timer 导致测试挂起
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('诊断开关默认关闭', (tester) async {
    final diag = DiagnosticsPrefs();
    expect(diag.enabled, isFalse);
  });
}
