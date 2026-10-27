import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_config.dart';
import '../../core/api/ibd_api_client.dart';
import '../../core/auth/auth_session.dart';
import '../../core/identity/local_identity.dart';
import '../../core/ui/theme.dart';

/// T5：患者侧医生数据源（可注入，便于测试与降级处理）。
abstract class DoctorPatientSource {
  Future<List<Map<String, dynamic>>> loadGrants();
  Future<List<Map<String, dynamic>>> loadNotes();
  Future<List<Map<String, dynamic>>> loadAudits();
  Future<void> confirm(String code, {List<String>? scope, String? wrappedDek});
  Future<void> revoke(String grantId);
}

class ApiDoctorPatientSource implements DoctorPatientSource {
  ApiDoctorPatientSource(this._api);
  final IbdApiClient _api;

  @override
  Future<List<Map<String, dynamic>>> loadGrants() => _api.myDoctorGrants();

  @override
  Future<List<Map<String, dynamic>>> loadNotes() => _api.doctorPatientNotes();

  @override
  Future<List<Map<String, dynamic>>> loadAudits() => _api.doctorPatientAudits();

  @override
  Future<void> confirm(
    String code, {
    List<String>? scope,
    String? wrappedDek,
  }) =>
      _api.confirmDoctorGrant(code, scope: scope, wrappedDek: wrappedDek);

  @override
  Future<void> revoke(String grantId) => _api.revokeDoctorGrant(grantId);
}

/// M1.3/M2.2：我的医生（授权码确认 / 列表 / 收回）。
/// T5：授权列表 / 医生建议 / 审计全部接真实 API（/doctor-grants/mine、/doctor-patient/*）。
class MyDoctorsPage extends StatefulWidget {
  const MyDoctorsPage({super.key, this.source});

  /// 测试注入；缺省走真实 API
  final DoctorPatientSource? source;

  @override
  State<MyDoctorsPage> createState() => _MyDoctorsPageState();
}

class _MyDoctorsPageState extends State<MyDoctorsPage> {
  final _codeCtrl = TextEditingController();
  final _dekCtrl = TextEditingController();
  bool _useWrappedDek = false;
  final Set<String> _picked = {'labs', 'symptoms'};
  /// T5：全部来自真实 API（此前为硬编码演示数据）
  List<Map<String, dynamic>> _grants = [];
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _audits = [];
  bool _loading = true;
  String? _loadError;
  bool _busy = false;

  static const _allScopes = ['labs', 'symptoms', 'alerts', 'summary'];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  DoctorPatientSource _src() {
    final injected = widget.source;
    if (injected != null) return injected;
    final identity = context.read<LocalIdentity>();
    final session = AuthSession.parseSession('', identity.uuid);
    return ApiDoctorPatientSource(IbdApiClient(ApiConfig.dev(), session));
  }

  /// T5：拉取授权/建议/审计真实数据；失败进入错误态（不伪造数据）。
  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final src = _src();
      final results = await Future.wait([
        src.loadGrants(),
        src.loadNotes(),
        src.loadAudits(),
      ]);
      if (!mounted) return;
      setState(() {
        // List.of：保证本地降级路径可增长（API/测试源可能给不可变列表）
        _grants = List.of(results[0]);
        _notes = List.of(results[1]);
        _audits = List.of(results[2]);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '加载失败（离线或未登录会话），可重试；授权码确认仍可离线记录';
      });
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _dekCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmLocal() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    if (_picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少勾选一个授权范围')),
      );
      return;
    }
    // T5：确认走真实 API；成功刷新真实列表。失败降级为"本地未同步"记录
    //（不伪称已确认），离线补录待网络恢复后重新确认。
    setState(() => _busy = true);
    var synced = false;
    try {
      await _src().confirm(
        code,
        scope: _picked.toList(),
        wrappedDek: _useWrappedDek && _dekCtrl.text.trim().isNotEmpty
            ? _dekCtrl.text.trim()
            : null,
      );
      synced = true;
    } catch (_) {
      synced = false;
    }
    if (!mounted) return;
    if (synced) {
      await _loadAll();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已确认范围 ${_picked.join('/')}')),
      );
    } else {
      setState(() {
        _busy = false;
        _grants.insert(0, {
          'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
          'scope': _picked.join(','),
          'confirmed': false,
          'localOnly': true,
          'expiresAt':
              DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        });
        _codeCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('离线：已本地记录（未同步到服务端）')),
      );
    }
  }

  Future<void> _revoke(int i) async {
    final g = _grants[i];
    final id = '${g['id'] ?? ''}';
    if (id.isEmpty) return;
    if (id.startsWith('local-')) {
      // 本地未同步记录：仅本地标记
      setState(() {
        _grants[i] = {...g, 'revokedAt': DateTime.now().toIso8601String()};
      });
      return;
    }
    // T5：收回传 grantId（此前误传 code）；失败如实提示，不伪称已收回
    try {
      await _src().revoke(id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收回失败，请检查网络后重试')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _grants[i] = {...g, 'revokedAt': DateTime.now().toIso8601String()};
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已收回授权')),
    );
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
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          if (_loadError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: IbdColors.warning),
              ),
              child: Text(_loadError!,
                  style: const TextStyle(fontSize: 12, color: IbdColors.textSecondary)),
            ),
            TextButton(
              onPressed: _loading ? null : _loadAll,
              child: const Text('重试'),
            ),
          ],
          if (!_loading && _loadError == null && _grants.isEmpty)
            const Text('暂无授权',
                style: TextStyle(color: IbdColors.textSecondary)),
          ..._grants.asMap().entries.map((e) {
            final g = e.value;
            final revoked = g['revokedAt'] != null;
            final localOnly = g['localOnly'] == true;
            final scope = g['scope'];
            final scopeText = scope is List ? scope.join('/') : '$scope';
            final statusText = revoked
                ? '已收回'
                : localOnly
                    ? '本地未同步'
                    : (g['confirmed'] == true ? '已确认' : '待确认');
            final code = g['code'];
            final expiresAt = '${g['expiresAt'] ?? g['expires'] ?? ''}';
            return Card(
              child: ListTile(
                dense: true,
                title: Text(code != null
                    ? '授权码 $code'
                    : '医生 ${g['doctorId'] ?? ''}'),
                subtitle: Text(
                  '范围 $scopeText · 过期 $expiresAt · $statusText',
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
          const SizedBox(height: 20),
          const Text('医生建议',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          if (!_loading && _notes.isEmpty)
            const Text('暂无建议',
                style: TextStyle(color: IbdColors.textSecondary)),
          ..._notes.map(
            (n) => Card(
              child: ListTile(
                dense: true,
                title: Text('${n['content'] ?? ''}'),
                subtitle: Text(
                  '${n['createdAt'] ?? n['date'] ?? ''}'
                  '${n['doctorId'] != null ? ' · 医生 ${n['doctorId']}' : ''}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('授权审计',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          if (!_loading && _audits.isEmpty)
            const Text('暂无审计记录',
                style: TextStyle(color: IbdColors.textSecondary)),
          ..._audits.map(
            (a) => ListTile(
              dense: true,
              title: Text('${a['action']}'),
              subtitle: Text('${a['createdAt'] ?? a['at'] ?? ''}'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '数据来自本人授权记录（/doctor-grants、/doctor-patient）；仅显示本账号数据。',
            style: TextStyle(fontSize: 12, color: IbdColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
