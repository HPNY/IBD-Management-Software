import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_config.dart';
import 'core/api/ibd_api_client.dart';
import 'core/auth/auth_session.dart';
import 'core/auth/token_store.dart';
import 'features/auth/login_page.dart';
import 'features/injection/injection_page.dart';
import 'features/lab/lab_manual_page.dart';
import 'features/parse/parse_upload_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = ApiConfig.dev();
  final session = AuthSession(config, TokenStore());
  runApp(
    ChangeNotifierProvider.value(
      value: session,
      child: IbdApp(config: config),
    ),
  );
}

class IbdApp extends StatefulWidget {
  const IbdApp({super.key, required this.config});

  final ApiConfig config;

  @override
  State<IbdApp> createState() => _IbdAppState();
}

class _IbdAppState extends State<IbdApp> {
  AuthSession get _session => context.read<AuthSession>();
  late final IbdApiClient _api = IbdApiClient(widget.config, _session);
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    // 首帧后恢复 token，避免在 build 前依赖 context.read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _session.restore().whenComplete(() {
        if (mounted) setState(() => _restored = true);
      });
    });
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '肠安通',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
        useMaterial3: true,
      ),
      home: !_restored
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : Consumer<AuthSession>(
              builder: (context, session, _) {
                if (!session.isLoggedIn) return const LoginPage();
                return HomePage(api: _api, session: session);
              },
            ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.api, required this.session});

  final IbdApiClient api;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('肠安通'),
        actions: [
          IconButton(
            tooltip: '退出登录',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthSession>().logout(),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('上传检验报告'),
            subtitle: const Text('直传 → BullMQ 解析'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ParseUploadPage(api: api),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('手动录入检验'),
            subtitle: const Text('纸质/图片报告补录'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LabManualPage(api: api),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.vaccines),
            title: const Text('注射排期'),
            subtitle: const Text('协议生成 · 到期提醒 · 延迟顺延'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => InjectionPage(api: api),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
