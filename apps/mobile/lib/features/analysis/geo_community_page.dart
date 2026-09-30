import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_config.dart';
import '../../core/api/ibd_api_client.dart';
import '../../core/auth/auth_session.dart';
import '../../core/geo/geo_profile.dart';
import '../../core/identity/local_identity.dart';
import '../../core/ui/theme.dart';

/// D3：同城病友 + 就诊指南（匿名昵称+城市，无精确位置）。
class GeoCommunityPage extends StatefulWidget {
  const GeoCommunityPage({super.key});

  @override
  State<GeoCommunityPage> createState() => _GeoCommunityPageState();
}

class _GeoCommunityPageState extends State<GeoCommunityPage> {
  final _nickCtrl = TextEditingController();
  final _postCtrl = TextEditingController();
  String _city = '北京';
  String? _savedNick;
  String? _savedCity;
  bool _inited = false;
  final List<String> _localPosts = [];
  List<Map<String, dynamic>> _remotePosts = [];
  List<Map<String, dynamic>> _cityStats = [];
  bool _online = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    _postCtrl.dispose();
    super.dispose();
  }

  IbdApiClient _api() {
    final identity = context.read<LocalIdentity>();
    final session = AuthSession.parseSession('', identity.uuid);
    return IbdApiClient(ApiConfig.dev(), session);
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
    await _refreshRemote();
  }

  Future<void> _refreshRemote() async {
    final city = _savedCity ?? _city;
    try {
      final api = _api();
      final cities = await api.geoCities();
      final posts = await api.geoPosts(city);
      if (!mounted) return;
      setState(() {
        _online = true;
        _cityStats = cities
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _remotePosts = posts
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _online = false);
    }
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
    await _refreshRemote();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存（本机）：$nick · $_city')),
    );
  }

  Future<void> _submitPost() async {
    final t = _postCtrl.text.trim();
    if (t.isEmpty) return;
    final city = _savedCity ?? _city;
    try {
      final api = _api();
      await api.createGeoPost(
        city: city,
        content: t,
        nickname: _savedNick ?? '匿名',
      );
      _postCtrl.clear();
      await _refreshRemote();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已发布匿名帖')));
      }
    } catch (_) {
      setState(() {
        _localPosts.insert(0, t);
        _postCtrl.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络不可用，已存本机草稿')),
        );
      }
    }
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
          Text(
            '同城病友计数 · ${_online ? '已联网' : '离线'}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          if (_cityStats.isEmpty)
            const Text('暂无城市统计（离线或无数据）',
                style: TextStyle(color: IbdColors.textSecondary)),
          ..._cityStats.map(
            (s) => ListTile(
              dense: true,
              leading: const Icon(Icons.location_city, size: 18),
              title: Text('${s['city']}'),
              subtitle: Text('成员 ${s['members'] ?? 0} · 帖 ${s['posts'] ?? 0}'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '同城匿名帖 · ${_savedCity ?? _city}（公开匿名，勿写病历）',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _postCtrl,
                  decoration: const InputDecoration(
                    hintText: '发一条匿名帖…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _submitPost(),
                child: const Text('发帖'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_remotePosts.isEmpty && _localPosts.isEmpty)
            const Text('暂无帖',
                style: TextStyle(color: IbdColors.textSecondary)),
          ..._remotePosts.map(
            (p) => Card(
              child: ListTile(
                dense: true,
                title: Text('${p['content'] ?? ''}',
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text('${p['nickname'] ?? '匿名'} · ${p['city'] ?? ''}'),
              ),
            ),
          ),
          ..._localPosts.map(
            (p) => Card(
              child: ListTile(
                dense: true,
                title: Text(p, style: const TextStyle(fontSize: 13)),
                subtitle: Text('本机草稿 · ${_savedNick ?? '匿名'}'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '城市计数/帖流需联网服务端；失败自动降级本机草稿。',
            style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
