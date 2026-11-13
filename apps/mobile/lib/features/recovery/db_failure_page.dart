import 'package:flutter/material.dart';

import '../../core/db/local_db.dart';
import '../../core/ui/theme.dart';

/// U16：本地库打不开时的恢复页。
///
/// 真实场景：重装/换机后 Keystore 里的密钥与旧库文件不匹配（SQLCipher 报
/// `file is not a database`），此前 App 会停在满屏空白，用户完全不知道发生了什么。
/// 这里给出可理解的解释与两条出路：重试 / 重建本地库（不可逆，需二次确认）。
class DbFailurePage extends StatefulWidget {
  const DbFailurePage({
    super.key,
    required this.error,
    required this.onRecovered,
  });

  final Object error;
  final VoidCallback onRecovered;

  @override
  State<DbFailurePage> createState() => _DbFailurePageState();
}

class _DbFailurePageState extends State<DbFailurePage> {
  bool _busy = false;
  String? _lastError;

  Future<void> _retry() async {
    setState(() {
      _busy = true;
      _lastError = null;
    });
    try {
      await LocalDb.instance.database.timeout(const Duration(seconds: 10));
      if (!mounted) return;
      widget.onRecovered();
    } catch (e) {
      if (mounted) setState(() => _lastError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRebuild() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重建本地库？'),
        content: const Text(
          '这会删除本机所有病程记录，且无法撤销。\n\n'
          '如果你导出过 JSON 备份，或开启过云同步（端到端密文），'
          '重建后可以在「我的」里恢复。\n\n'
          '确定要清空本机数据吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.ibd.danger,
              minimumSize: const Size(64, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空并重建'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await LocalDb.instance.resetLocalDb();
      await LocalDb.instance.database.timeout(const Duration(seconds: 10));
      if (!mounted) return;
      widget.onRecovered();
    } catch (e) {
      if (mounted) setState(() => _lastError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ibd.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.storage_rounded, size: 44, color: context.ibd.danger),
                const SizedBox(height: 16),
                Text(
                  '本机数据打不开',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.ibd.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '本地加密库的密钥与数据文件对不上，常见于重装 App、'
                  '换机恢复或系统清理过应用数据。你的记录仍然在这台设备上，'
                  '但当前密钥无法解开它。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: context.ibd.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _busy ? null : _retry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(_busy ? '正在重试…' : '重试打开'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                    foregroundColor: context.ibd.danger,
                    side: BorderSide(color: context.ibd.danger),
                  ),
                  onPressed: _busy ? null : _confirmRebuild,
                  child: const Text('清空本机数据并重建'),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.ibd.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.ibd.divider),
                  ),
                  child: Text(
                    '排查线索（反馈问题时可复制）：\n${_lastError ?? widget.error}',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: context.ibd.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
