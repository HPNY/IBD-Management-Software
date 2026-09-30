import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ui/theme.dart';

/// M1.3/M2.2：我的医生（授权码确认 / 列表 / 收回）。
class MyDoctorsPage extends StatefulWidget {
  const MyDoctorsPage({super.key});

  @override
  State<MyDoctorsPage> createState() => _MyDoctorsPageState();
}

class _MyDoctorsPageState extends State<MyDoctorsPage> {
  final _codeCtrl = TextEditingController();
  final _dekCtrl = TextEditingController();
  bool _useWrappedDek = false;
  final Set<String> _picked = {'labs', 'symptoms'};
  final List<Map<String, String>> _grants = [];
  bool _busy = false;

  static const _allScopes = ['labs', 'symptoms', 'alerts', 'summary'];

  @override
  void dispose() {
    _codeCtrl.dispose();
    _dekCtrl.dispose();
    super.dispose();
  }

  void _confirmLocal() {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    if (_picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少勾选一个授权范围')),
      );
      return;
    }
    // 本地骨架：确认后进入列表；生产应 POST /doctor-grants/confirm
    setState(() {
      _grants.insert(0, {
        'code': code,
        'scope': _picked.join(','),
        'status': 'confirmed',
        'expires': DateTime.now()
            .add(const Duration(hours: 24))
            .toIso8601String(),
      });
      _codeCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已确认范围 ${_picked.join('/')}（本机演示）')),
    );
  }

  void _revoke(int i) {
    setState(() => _grants[i]['status'] = 'revoked');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(title: const Text('我的医生')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '仅授权后医生可查看指定范围；可随时收回。授权码由医生端生成。',
            style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
          ),
          const SizedBox(height: 12),
          const Text('扫码/输入授权码',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _codeCtrl,
            decoration: const InputDecoration(
              labelText: '授权码',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          const Text('授权范围（未勾选不可确认）',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Wrap(
            spacing: 8,
            children: [
              for (final s in _allScopes)
                FilterChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  selected: _picked.contains(s),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _picked.add(s);
                    } else {
                      _picked.remove(s);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            dense: true,
            title: const Text('附带 DEK 再包裹密文（可选）'),
            subtitle: const Text('服务端不保存明文密钥；请粘贴医生公钥包裹后的密文'),
            value: _useWrappedDek,
            onChanged: (v) => setState(() => _useWrappedDek = v),
          ),
          if (_useWrappedDek)
            TextField(
              controller: _dekCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'wrappedDek（base64）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _confirmLocal,
            child: const Text('确认授权'),
          ),
          const SizedBox(height: 20),
          const Text('我的授权',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          if (_grants.isEmpty)
            const Text('暂无授权',
                style: TextStyle(color: IbdColors.textSecondary)),
          ..._grants.asMap().entries.map((e) {
            final g = e.value;
            final revoked = g['status'] == 'revoked';
            return Card(
              child: ListTile(
                dense: true,
                title: Text('${g['code']}'),
                subtitle: Text(
                  '范围 ${g['scope']} · 过期 ${g['expires']} · ${g['status']}',
                ),
                trailing: revoked
                    ? null
                    : TextButton(
                        onPressed: () => _revoke(e.key),
                        child: const Text('收回'),
                      ),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text(
            '本页为 M2 本地交互骨架；接后端后替换为 /doctor-grants API。',
            style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
