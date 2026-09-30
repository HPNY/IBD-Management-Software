import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/geo/geo_profile.dart';
import '../../core/ui/theme.dart';

/// D3：同城病友 + 就诊指南（匿名昵称+城市，无精确位置）。
class GeoCommunityPage extends StatefulWidget {
  const GeoCommunityPage({super.key});

  @override
  State<GeoCommunityPage> createState() => _GeoCommunityPageState();
}

class _GeoCommunityPageState extends State<GeoCommunityPage> {
  final _nickCtrl = TextEditingController();
  String _city = '北京';
  String? _savedNick;
  String? _savedCity;
  bool _inited = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final sp = await SharedPreferences.getInstance();
    final nick = sp.getString('geo_nickname');
    final city = sp.getString('geo_city') ?? '北京';
    if (!mounted) return;
    setState(() {
      _inited = true;
      _city = city;
      _savedCity = nick == null ? null : city;
      _savedNick = nick;
      if (nick != null) _nickCtrl.text = nick;
    });
  }

  Future<void> _saveProfile() async {
    final nick = _nickCtrl.text.trim();
    if (nick.isEmpty) return;
    final p = GeoProfile(nickname: nick, city: _city);
    assertNoPreciseLocation(p.toPublicJson());
    final sp = await SharedPreferences.getInstance();
    await sp.setString('geo_nickname', nick);
    await sp.setString('geo_city', _city);
    if (!mounted) return;
    setState(() {
      _savedNick = nick;
      _savedCity = _city;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存（本机）：$nick · $_city')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_inited) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final guides = guidesForCity(_savedCity ?? _city);
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(title: const Text('同城病友 · 就诊指南')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '匿名显示（昵称+城市），不采集精确位置。帖子默认公开匿名，请勿写真实病历。',
            style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
          ),
          const SizedBox(height: 12),
          const Text('我的城市与昵称',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _nickCtrl,
            decoration: const InputDecoration(
              labelText: '昵称（可随时改）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _city,
            decoration: const InputDecoration(
              labelText: '城市',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final c in kCities)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _city = v ?? _city),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _saveProfile, child: const Text('保存档案')),
          if (_savedNick != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('当前：$_savedNick · $_savedCity'),
            ),
          const SizedBox(height: 20),
          Text(
            '就诊指南 · ${_savedCity ?? _city}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (guides.isEmpty)
            const Text('暂无该城市指南，可换城市查看',
                style: TextStyle(color: IbdColors.textSecondary)),
          ...guides.map(
            (g) => Card(
              child: ListTile(
                dense: true,
                title: Text(g.hospital),
                subtitle: Text(
                  '${g.department}${g.specialty != null ? ' · ${g.specialty}' : ''}'
                  '${g.tips != null ? '\n${g.tips}' : ''}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '同城病友计数/匿名帖需联网服务端；本页先提供档案与指南（D3.1–D3.2）。',
            style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
