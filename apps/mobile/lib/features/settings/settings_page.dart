import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_config.dart';
import '../../core/api/sync_api.dart';
import '../../core/auth/auth_session.dart';
import '../../core/backup/backup_service.dart';
import '../../core/db/local_db.dart';
import '../../core/identity/local_identity.dart';
import '../../core/push/push_service.dart';
import '../../core/skill/local_skill_store.dart';
import '../../core/ui/theme.dart';
import '../auth/login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.embedded = false,
    this.syncOn = false,
  });

  final bool embedded;
  final bool syncOn;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final BackupService _backup =
      BackupService(context.read<LocalIdentity>().uuid);
  late final PushService _push = PushService(
    identity: context.read<LocalIdentity>(),
    config: ApiConfig.dev(),
  );
  bool _busy = false;
  String? _message;
  Map<String, Object?>? _dbProbe;

  @override
  void initState() {
    super.initState();
    _loadDbProbe();
    _push.addListener(_onPushChanged);
    _push.load();
  }

  @override
  void dispose() {
    _push.removeListener(_onPushChanged);
    _push.dispose();
    super.dispose();
  }

  void _onPushChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDbProbe() async {
    try {
      final probe = await LocalDb.instance.probe();
      if (mounted) setState(() => _dbProbe = probe);
    } catch (e) {
      if (mounted) setState(() => _dbProbe = {'error': e.toString()});
    }
  }

  Future<void> _setPassphraseAndSync() async {
    final ctrl = TextEditingController();
    final identity = context.read<LocalIdentity>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置备份口令'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '口令（仅本机保存，用于加密云备份）',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    await _backup.savePassphrase(ctrl.text.trim());
    await identity.setSyncOptIn(true);
    if (mounted) setState(() => _message = '已开启云同步（密文）');
  }

  Future<void> _pushCipher() async {
    final identity = context.read<LocalIdentity>();
    if (!identity.syncOptIn) {
      setState(() => _message = '请先开启云同步并设置口令');
      return;
    }
    final pass = await _backup.loadPassphrase();
    if (pass == null) {
      setState(() => _message = '缺少备份口令');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final snap = await _backup.encryptSnapshot(pass);
      final session = await SyncApi(ApiConfig.dev()).syncSession(identity.uuid);
      await SyncApi(ApiConfig.dev()).putCipher(
        token: session['accessToken'] as String,
        appUserId: identity.uuid,
        dataType: 'full',
        cipher: snap['cipher']!,
        nonce: snap['nonce']!,
        mac: snap['mac']!,
        clientUpdatedAt: DateTime.now().toIso8601String(),
        version: DateTime.now().millisecondsSinceEpoch,
      );
      setState(() => _message = '密文快照已上传（含 MAC）');
    } catch (e) {
      setState(() => _message = '上传失败：$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromCloud() async {
    final identity = context.read<LocalIdentity>();
    final pass = await _backup.loadPassphrase();
    if (pass == null) {
      setState(() => _message = '请先设置备份口令');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final session = await SyncApi(ApiConfig.dev()).syncSession(identity.uuid);
      final list = await SyncApi(ApiConfig.dev()).listCipher(
        token: session['accessToken'] as String,
        appUserId: identity.uuid,
      );
      if (list.isEmpty) {
        setState(() => _message = '云端暂无快照');
        return;
      }
      final snap = Map<String, dynamic>.from(list.first as Map);
      final n = await _backup.restoreFromCloud(
        passphrase: pass,
        cipher: snap['cipher'] as String,
        nonce: snap['nonce'] as String,
        mac: (snap['mac'] as String?) ?? '',
      );
      setState(() => _message = '已从云端恢复 $n 条记录');
    } catch (e) {
      setState(() => _message = '恢复失败：$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final path = await _backup.exportToFile();
      await Share.shareXFiles([XFile(path)], text: 'IBDers 本地备份');
      setState(() => _message = '已导出 $path');
    } catch (e) {
      setState(() => _message = '导出失败：$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.singleOrNull?.bytes;
    if (bytes == null) return;
    setState(() => _busy = true);
    try {
      await _backup.importFromJsonString(String.fromCharCodes(bytes));
      setState(() => _message = '导入完成');
    } catch (e) {
      setState(() => _message = '导入失败：$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _toggleSystemPush(bool v) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final ok = v ? await _push.enable() : await _push.disable();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok
          ? (v ? '系统推送已开启（远程 opt-in，仅通用提醒）' : '系统推送已关闭并注销设备令牌')
          : (_push.lastError ?? '操作失败');
    });
  }

  Future<void> _unregisterPushToken() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注销推送设备？'),
        content: const Text(
          '将从服务端删除本机推送令牌（只绑 app_user_uuid，与登录无关）。\n'
          '本地提醒不受影响；可随时重新开启。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('注销'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final done = await _push.disable();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = done
          ? '设备令牌已注销'
          : (_push.lastError ?? '注销失败');
    });
  }

  Future<void> _testSystemPush() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final msg = await _push.testRemotePing();
      setState(() => _message = msg);
    } catch (e) {
      setState(() => _message = '测试失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _wipeCloud() async {
    final identity = context.read<LocalIdentity>();
    final pass = await _backup.loadPassphrase();
    if (pass == null) {
      setState(() => _message = '缺少备份口令，无法证明身份');
      return;
    }
    setState(() => _busy = true);
    try {
      final session = await SyncApi(ApiConfig.dev()).syncSession(identity.uuid);
      await SyncApi(ApiConfig.dev()).wipe(
        token: session['accessToken'] as String,
        appUserId: identity.uuid,
      );
      await identity.setSyncOptIn(false);
      setState(() => _message = '云端副本已删除，同步已关闭');
    } catch (e) {
      setState(() => _message = '删除失败：$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<LocalIdentity>();
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(widget.embedded ? '我的' : '隐私与备份'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (widget.embedded)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '本机身份',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          identity.uuid.substring(0, 8),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          identity.syncOptIn ? '云同步已开启' : '仅本机 · 未同步',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.psychology_alt_rounded),
              title: const Text('AI 解析（可选）'),
              subtitle: const Text(
                '未配置 LLM_API_KEY 时走 Skill；否则 Skill 未命中走 LLM',
              ),
              trailing: FutureBuilder<int>(
                future: LocalSkillStore.count(),
                builder: (c, snap) => Text(
                  'Skill ${snap.data ?? 0}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.notifications_active_rounded),
              title: Text('注射提醒（本地）'),
              subtitle: Text(
                '本地通知（提前 3 天）；关网可用，不依赖推送',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('系统推送（可选）', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '远程推送默认关闭。开启后仅注册设备令牌（只绑本机 app_user_uuid，'
            '不强制登录），正文只给通用文案（如「您有一条用药提醒」），'
            '不携带药品/剂量/病历。可随时注销；不把推送做成登录门禁。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('开启系统推送'),
            subtitle: Text(
              _push.optIn
                  ? '已开启 · 令牌 ${_push.registeredTokenPrefix ?? '—'}…'
                  : '关闭时零远程注册；本地注射提醒不受影响',
            ),
            value: _push.optIn,
            onChanged: _busy || _push.busy ? null : _toggleSystemPush,
          ),
          Row(
            children: [
              TextButton(
                onPressed: _busy || _push.busy || !_push.optIn
                    ? null
                    : _unregisterPushToken,
                child: Text(
                  '注销设备令牌',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              TextButton(
                onPressed: _busy || _push.busy || !_push.optIn
                    ? null
                    : _testSystemPush,
                child: const Text('测试通用提醒'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('应用标识（本机）', style: Theme.of(context).textTheme.titleSmall),
          SelectableText(identity.uuid),
          const SizedBox(height: 12),
          if (_dbProbe != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('本地库 SQLCipher'),
                subtitle: Text(
                  _dbProbe!['error'] != null
                      ? '${_dbProbe!['error']}'
                      : 'provider=${_dbProbe!['cipherProvider']} · '
                          'key=${_dbProbe!['hasKey'] == true ? '已生成' : '缺失'} · '
                          'size=${_dbProbe!['sizeBytes']}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadDbProbe,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('云同步（可选）', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '病历默认只存在本机，不上传服务器。开启同步或关联手机号前，'
            '数据完全留在你的设备上；可随时关闭、注销关联、删除云端副本。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('启用云同步（端到端密文）'),
            subtitle: const Text('需设置备份口令；服务端无法解密病历'),
            value: identity.syncOptIn,
            onChanged: (v) async {
              if (v) {
                await _setPassphraseAndSync();
              } else {
                await identity.setSyncOptIn(false);
                setState(() {});
              }
            },
          ),
          _PhoneLinkCard(
            onOpen: () async {
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
              if (mounted) setState(() {});
            },
          ),
          FilledButton(
            onPressed: _busy ? null : _pushCipher,
            child: Text(_busy ? '处理中…' : '上传加密快照'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _busy ? null : _restoreFromCloud,
            child: const Text('从云端恢复（换机）'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _export,
            child: const Text('导出本地备份 JSON'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : _import,
            child: const Text('导入备份 JSON'),
          ),
          TextButton(
            onPressed: _busy ? null : _wipeCloud,
            child: Text(
              '删除云端副本',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!),
            ),
        ],
      ),
    );
  }
}

/// 可选「关联手机号」：非登录墙；强调本地存储与可注销。
class _PhoneLinkCard extends StatelessWidget {
  const _PhoneLinkCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final linked = auth.isLoggedIn;
    final phone = auth.tokens?.phone;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        leading: Icon(
          linked ? Icons.phone_iphone_rounded : Icons.phone_android_outlined,
        ),
        title: Text(linked ? '已关联手机号' : '关联手机号（可选）'),
        subtitle: Text(
          linked
              ? '${phone != null && phone.isNotEmpty ? maskPhone(phone) : '已关联'} · 仅用于换机恢复 / 多端密文同步，可随时注销。病历仍在本机。'
              : '可选能力，不是登录墙。未关联也可完整使用本机功能；关联仅服务换机恢复与密文同步。',
        ),
        trailing: linked
            ? TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('注销关联？'),
                      content: const Text(
                        '将解除本机与手机号的关联（不影响本机病历）。\n'
                        '云端密文副本需另行在「删除云端副本」中处理。',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('注销关联'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  await context.read<AuthSession>().logout();
                },
                child: Text('注销', style: TextStyle(color: scheme.error)),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: linked ? null : onOpen,
      ),
    );
  }

  static String maskPhone(String phone) {
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }
}
