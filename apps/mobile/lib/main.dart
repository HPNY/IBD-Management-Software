import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/identity/local_identity.dart';
import 'features/home/home_page.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
        useMaterial3: true,
      ),
      // 本地优先：无登录门禁
      home: const HomePage(),
    );
  }
}
