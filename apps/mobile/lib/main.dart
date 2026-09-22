import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_config.dart';
import 'core/auth/auth_session.dart';
import 'core/auth/token_store.dart';
import 'core/identity/local_identity.dart';
import 'core/ui/theme.dart';
import 'features/shell_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final identity = LocalIdentity();
  await identity.load();
  final auth = AuthSession(ApiConfig.dev(), TokenStore());
  await auth.restore();
  runApp(
    MultiProvider(
      providers: [
        Provider<LocalIdentity>.value(value: identity),
        ChangeNotifierProvider<AuthSession>.value(value: auth),
      ],
      child: const IbdApp(),
    ),
  );
}

class IbdApp extends StatelessWidget {
  const IbdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IBDers',
      debugShowCheckedModeBanner: false,
      theme: buildIbdTheme(),
      darkTheme: buildIbdDarkTheme(),
      themeMode: ThemeMode.system,
      home: const ShellPage(),
    );
  }
}
