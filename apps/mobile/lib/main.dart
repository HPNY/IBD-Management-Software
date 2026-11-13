import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_config.dart';
import 'core/auth/auth_session.dart';
import 'core/auth/token_store.dart';
import 'core/diagnostics/diagnostics_prefs.dart';
import 'core/i18n/app_locale.dart';
import 'core/identity/local_identity.dart';
import 'core/ui/accessibility.dart';
import 'core/db/local_db.dart';
import 'core/ui/theme.dart';
import 'features/recovery/db_failure_page.dart';
import 'features/shell_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final identity = LocalIdentity();
  await identity.load();
  final auth = AuthSession(ApiConfig.dev(), TokenStore());
  await auth.restore();
  final a11y = AccessibilityPrefs();
  await a11y.load();
  final locale = AppLocale();
  await locale.load();
  final diagnostics = DiagnosticsPrefs();
  await diagnostics.load();

  // U16：启动即探测本地库。打不开时进恢复页，而不是让每个页面各自渲染成空白。
  Object? dbError;
  try {
    await LocalDb.instance.database.timeout(const Duration(seconds: 10));
  } catch (e) {
    dbError = e;
  }

  runApp(
    _buildRoot(
      identity: identity,
      auth: auth,
      a11y: a11y,
      locale: locale,
      diagnostics: diagnostics,
      dbError: dbError,
    ),
  );
}

/// 根组件：库正常则进 App，异常则进恢复页；恢复成功后原地重建。
Widget _buildRoot({
  required LocalIdentity identity,
  required AuthSession auth,
  required AccessibilityPrefs a11y,
  required AppLocale locale,
  required DiagnosticsPrefs diagnostics,
  required Object? dbError,
}) {
  return MultiProvider(
    providers: [
      Provider<LocalIdentity>.value(value: identity),
      ChangeNotifierProvider<AuthSession>.value(value: auth),
      ChangeNotifierProvider<AccessibilityPrefs>.value(value: a11y),
      ChangeNotifierProvider<AppLocale>.value(value: locale),
      ChangeNotifierProvider<DiagnosticsPrefs>.value(value: diagnostics),
    ],
    child: dbError == null
        ? const IbdApp()
        : MaterialApp(
            title: 'IBDers',
            debugShowCheckedModeBanner: false,
            theme: buildIbdTheme(),
            darkTheme: buildIbdDarkTheme(),
            themeMode: ThemeMode.system,
            home: DbFailurePage(
              error: dbError,
              onRecovered: () => runApp(
                _buildRoot(
                  identity: identity,
                  auth: auth,
                  a11y: a11y,
                  locale: locale,
                  diagnostics: diagnostics,
                  dbError: null,
                ),
              ),
            ),
          ),
  );
}

class IbdApp extends StatelessWidget {
  const IbdApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppLocale>();
    return MaterialApp(
      title: 'IBDers',
      debugShowCheckedModeBanner: false,
      locale: locale.locale,
      theme: buildIbdTheme(),
      darkTheme: buildIbdDarkTheme(),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        final scale = context.watch<AccessibilityPrefs>().textScale;
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const ShellPage(),
    );
  }
}
