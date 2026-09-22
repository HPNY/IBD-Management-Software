import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_session.dart';

/// 可选「关联手机号」——不是登录墙。
/// 病历始终在本机；关联仅用于密文同步/换机恢复等可选云能力。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController(text: '123456');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthSession>().login(
            phone: _phoneCtrl.text.trim(),
            code: _codeCtrl.text.trim(),
          );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('关联手机号（可选）')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'IBDers 默认完全本地使用，不需要账号。\n'
            '关联手机号仅用于换机恢复、多端密文同步等可选能力。\n'
            '病历仍保存在本机，未授权不会上传服务器。\n'
            '可随时在设置中注销关联；注销不影响本机数据。',
            style: TextStyle(color: secondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '手机号',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '验证码（开发默认 123456）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _link,
            child: Text(_busy ? '关联中…' : '关联手机号'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('暂不关联，继续本地使用'),
          ),
          if (context.watch<AuthSession>().isLoggedIn)
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final nav = Navigator.of(context);
                      final auth = context.read<AuthSession>();
                      setState(() => _busy = true);
                      try {
                        await auth.logout();
                        if (!mounted) return;
                        setState(() => _error = null);
                        nav.maybePop();
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: Text(
                '注销关联',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
