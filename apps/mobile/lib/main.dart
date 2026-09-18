import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/identity/local_identity.dart';
import 'core/ui/theme.dart';
import 'features/shell_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final identity = LocalIdentity();
  await identity.load();
  runApp(
    Provider<LocalIdentity>.value(
      value: identity,
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
