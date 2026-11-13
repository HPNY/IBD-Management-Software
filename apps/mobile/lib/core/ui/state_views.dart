import 'package:flutter/material.dart';

import 'theme.dart';

/// U14：统一的加载 / 错误 / 空态。
///
/// 背景：真机回归发现「药物评价」「同城病友」「年度报告」在异步失败或卡住时
/// 整页渲染为纯空白（无 loading、无文案、无重试），用户无法判断是没数据、
/// 在加载、还是坏了。这三个组件保证任何分支都有可见反馈。
///
/// 约定：
/// - 加载态必须有文字说明在加载什么（不用裸转圈）。
/// - 错误态必须给「重试」，并保留可复制的原始信息（便于排查）。
/// - 空态必须给下一步动作，不能只有一句"暂无"。

class IbdLoadingView extends StatelessWidget {
  const IbdLoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(
              label!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.ibd.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class IbdErrorView extends StatelessWidget {
  const IbdErrorView({
    super.key,
    required this.message,
    this.title = '加载失败',
    this.onRetry,
    this.detail,
  });

  final String title;
  final String message;

  /// 原始异常文本，折叠显示，便于反馈问题时复制。
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: context.ibd.danger),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.ibd.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.ibd.textSecondary,
              ),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.ibd.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.ibd.divider),
                ),
                child: Text(
                  detail!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: context.ibd.textSecondary,
                  ),
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 180,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('重试'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class IbdEmptyView extends StatelessWidget {
  const IbdEmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.ibd.brandSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: context.ibd.brandInk, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.ibd.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: context.ibd.textSecondary,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 200,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 列表内空态（U6）：用于「某个区块还没有记录」，
/// 而不是整页空。
///
/// 与 [IbdEmptyView] 的区别：不居中占满整页（在 `ListView` 里会因高度无界报错），
/// 而是一条矮卡片，横向排列图标 + 文案 + 可选动作。
/// 空态必须给出下一步，不能只写「暂无」。
class IbdEmptyInline extends StatelessWidget {
  const IbdEmptyInline({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.ibd.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.ibd.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.ibd.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: context.ibd.textSecondary,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
