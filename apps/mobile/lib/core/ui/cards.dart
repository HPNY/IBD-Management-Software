import 'package:flutter/material.dart';

import 'theme.dart';

/// U6：统一的展示层原语（卡片 / 区块标题 / 选项 chip / 吸附操作栏）。
///
/// 背景：仓库里「卡片 + 标题」这一个模式曾有 4 份实现
/// （`_SectionCard` / `_NavCard` / `_ModuleCard` / `_StatChip`），
/// 圆角、内边距、描边各不相同，改一处要改四处；
/// 选项 chip 也有 `_BloodChip` / `_FeelingChip`（两份逐字相同）+ `_QualityChip`，
/// 而 Material 的 `ChoiceChip` / `FilterChip` 又各自靠默认样式，共 4 套观感。
///
/// 约定：
/// - 卡片一律「浅描边 + 无阴影 + 大圆角」，颜色取自 `context.ibd`。
/// - 需要点击时传 [onTap]，水波纹与语义标签由这里统一处理。
/// - 区块标题一律用 [IbdSectionHeader]，不要再用裸 `Text` 或
///   `textTheme.titleSmall` 拼。
/// - 一组互斥选项用 [IbdChoiceChip]；0–10 这类数字刻度用 [IbdScoreChip]。
/// - 页面底部常驻的主操作 + 状态说明用 [IbdStickyAction]。
/// - 单个指标（数值块、状态灯）用 [IbdMetric]；**状态类指标必须带文字**，
///   不能只靠圆点颜色（WCAG 1.4.1）。

class IbdCard extends StatelessWidget {
  const IbdCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 20,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final card = Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? context.ibd.surface,
        borderRadius: r,
        border: Border.all(color: context.ibd.outline),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    // 可点击卡片合并成一个语义节点：读屏器一次读完「标题 + 摘要」，
    // 而不是先读标题、再读摘要、再读一个不知名的按钮。
    return onTap == null ? card : MergeSemantics(child: card);
  }
}

class IbdSectionHeader extends StatelessWidget {
  const IbdSectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 12),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.ibd.textPrimary,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 分段选择 chip：一组互斥选项里的单个。
///
/// [expanded] 为 true 时在所在 `Row` 中等分铺满（内部已包 `Expanded`，
/// 调用处不要再套），用于「三个选项并排占满一行」；
/// 为 false 时按内容宽，用于 `Wrap` 里的可换行选项组。
///
/// [color] 是**选中态强调色**，默认品牌绿。传入严重度色
/// （`context.ibd.danger` / `warning` / `success`）可让选中态表达医学语义。
///
/// 注：未选中底色用 `context.ibd.surface` 而不是写死白色——
/// 原实现写死 `Colors.white`，暗色模式下会得到白底 + 浅灰字。
class IbdChoiceChip extends StatelessWidget {
  const IbdChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.expanded = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.ibd.brandInk;
    final chip = Semantics(
      button: true,
      selected: selected,
      label: label,
      // excludeSemantics 会把子树的语义（含 InkWell 的 tap 动作）一起丢掉，
      // 所以这里必须重新挂一次 onTap，否则读屏会念「按钮」但双击没反应。
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.15)
                : context.ibd.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : context.ibd.divider,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? accent : context.ibd.textSecondary,
            ),
          ),
        ),
      ),
    );
    return expanded ? Expanded(child: chip) : chip;
  }
}

/// 数字刻度 chip（如生活质量 0–10）：方形、等宽、选中为品牌实心。
class IbdScoreChip extends StatelessWidget {
  const IbdScoreChip({
    super.key,
    required this.score,
    required this.selected,
    required this.onTap,
    this.size = 36,
  });

  final int score;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$score 分',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? context.ibd.brandInk : context.ibd.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? context.ibd.brandInk : context.ibd.divider,
            ),
          ),
          child: Text(
            '$score',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? context.ibd.onBrand : context.ibd.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 页面底部吸附操作栏：一个全宽主操作 + 一行状态说明。
///
/// 用于「表单很长，但保存必须随手可及」的页面（打卡、用药编辑等）。
/// 说明文字不是装饰——它承担「草稿存了没 / 存哪了」这类信任信息，
/// 所以必填，不允许只留一个按钮。
class IbdStickyAction extends StatelessWidget {
  const IbdStickyAction({
    super.key,
    required this.label,
    required this.onPressed,
    required this.hint,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 按钮下方那行状态说明（如「草稿已自动保存 10:21 · 仅存本机」）。
  final String hint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.ibd.surface,
        border: Border(top: BorderSide(color: context.ibd.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Block CTA：吸附区唯一主操作，占满整行（U17 分层）
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPressed,
                  icon: icon == null ? null : Icon(icon, size: 20),
                  label: Text(label),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.ibd.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 指标语义档位：决定圆点与状态文字的颜色。
enum IbdMetricTone {
  /// 无数据 / 中性
  neutral,

  /// 正常、达标
  ok,

  /// 需要留意（如接近阈值）
  warn,

  /// 偏高、异常
  bad;

  /// 把 `inflammationLight()` 的 `green` / `red` / `gray` 映射成视觉档位。
  ///
  /// 放在 UI 层而不是 `activity_service.dart`：那是领域层，不该依赖视觉枚举。
  static IbdMetricTone ofLight(String light) => switch (light) {
        'red' => IbdMetricTone.bad,
        'green' => IbdMetricTone.ok,
        _ => IbdMetricTone.neutral,
      };
}

/// 单个指标的展示单元。两种形态：
///
/// - [IbdMetric.stat] 横向数值块：图标 + 数值 + 标签（「检验记录 / 12」）。
///   它**不自带卡片容器**——需要白底卡片时外面套 [IbdCard]，这样同一个指标
///   也能直接放进已有卡片里，不会出现双重描边。
/// - [IbdMetric.status] 纵向状态灯：圆点 + 标签 + 数值 / 状态词 / 附注
///   （「● CRP / 偏高」，或详情页的「● CRP / 12 mg/L / 偏高 / 2026-11-01」）。
///
/// 状态灯的三条硬约定（都是踩过坑的）：
/// 1. **颜色不能是唯一编码**——必须给 [state] 文字，色盲与灰度下才读得出；
/// 2. 圆点色与文字色分开取：中性圆点用浅灰 `#CBD5E1`，那个颜色当文字只有
///    2.2:1，所以中性态的文字改用 `textSecondary`；
/// 3. 整块包 `Semantics` 并 `excludeSemantics`，读屏器读成「CRP 偏高」，
///    而不是「CRP」+ 一个无名圆点。
class IbdMetric extends StatelessWidget {
  /// 横向数值块：图标 + 数值 + 标签。
  const IbdMetric.stat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  })  : state = null,
        caption = null,
        tone = IbdMetricTone.neutral,
        dotSize = 0,
        _shape = _MetricShape.stat;

  /// 纵向状态灯：圆点 + 标签 + 可选的数值 / 状态词 / 附注。
  const IbdMetric.status({
    super.key,
    required this.label,
    this.value,
    this.state,
    this.caption,
    this.tone = IbdMetricTone.neutral,
    this.dotSize = 10,
  })  : icon = null,
        _shape = _MetricShape.status;

  final String label;

  /// 主数值（如 `12 mg/L`）。[IbdMetric.stat] 必填。
  final String? value;

  /// 状态词（`偏高` / `正常` / `未测`）。状态灯必填，是颜色之外的第二重编码。
  final String? state;

  /// 附注（如检验日期）。
  final String? caption;

  final IconData? icon;
  final IbdMetricTone tone;
  final double dotSize;

  final _MetricShape _shape;

  Color _toneColor(BuildContext context) => switch (tone) {
        IbdMetricTone.ok => context.ibd.success,
        IbdMetricTone.warn => context.ibd.warning,
        IbdMetricTone.bad => context.ibd.danger,
        IbdMetricTone.neutral => context.ibd.textSecondary,
      };

  /// 圆点色：中性态用浅灰（图形只需 3:1），其余跟档位色。
  Color _dotColor(BuildContext context) => tone == IbdMetricTone.neutral
      ? const Color(0xFFCBD5E1)
      : _toneColor(context);

  @override
  Widget build(BuildContext context) {
    if (_shape == _MetricShape.stat) {
      return Semantics(
        label: '$label ${value ?? ''}'.trim(),
        excludeSemantics: true,
        child: Row(
          children: [
            Icon(icon, color: context.ibd.brandInk, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.ibd.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.ibd.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: [label, value, state, caption]
          .where((e) => e != null && e.isNotEmpty)
          .join(' '),
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: _dotColor(context),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: dotSize <= 10 ? 4 : 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: dotSize <= 10 ? 11.5 : 12,
                    fontWeight: FontWeight.w700,
                    color: context.ibd.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (value != null && value!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              value!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: tone == IbdMetricTone.bad
                    ? context.ibd.danger
                    : context.ibd.textPrimary,
              ),
            ),
          ],
          if (state != null && state!.isNotEmpty) ...[
            SizedBox(height: value == null ? 3 : 1),
            Text(
              state!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _toneColor(context),
              ),
            ),
          ],
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              caption!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: context.ibd.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _MetricShape { stat, status }
