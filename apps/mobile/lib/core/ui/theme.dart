import 'package:flutter/material.dart';

/// 语义色板（U5）：页面只从这里取色，明暗两套值由主题注入。
///
/// 为什么需要它：`IbdColors` 是编译期常量，页面直接引用时永远拿到浅色值，
/// 暗色模式下会出现深字压深卡（实测 1.07:1）。改为 ThemeExtension 后，
/// 同一个 `context.ibd.surface` 在明/暗主题下自动取到对应色。
@immutable
class IbdPalette extends ThemeExtension<IbdPalette> {
  const IbdPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.divider,
    required this.brandInk,
    required this.onBrand,
    required this.brandSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.dangerSoft,
  });

  /// 页面底色
  final Color bg;

  /// 卡片 / 底栏底色
  final Color surface;

  /// 卡片内的次级区块（如行内编辑器）
  final Color surfaceAlt;

  final Color textPrimary;
  final Color textSecondary;

  /// 1px 描边（浅色为 4% 黑，暗色为 8% 白）
  final Color outline;

  /// 分隔线 / 输入框边线 / 进度条底槽
  final Color divider;

  /// 品牌强调色，用于文字与图标，也用作小面积实心填充
  final Color brandInk;

  /// 压在 [brandInk] 实心填充之上的文字/图标色。
  /// 浅色为白（5.47:1），暗色为深底（≈11:1）——brandInk 在暗色下是亮青，
  /// 若沿用白色文字会几乎不可读（U5 真机曾出现同类问题）。
  final Color onBrand;

  /// 品牌浅底（选中态、徽标底）
  final Color brandSoft;

  final Color success;
  final Color warning;
  final Color danger;
  final Color dangerSoft;

  static const light = IbdPalette(
    bg: Color(0xFFF4F7F6),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBFDFC),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    outline: Color(0x0A000000),
    divider: Color(0xFFE2E8F0),
    brandInk: Color(0xFF0F766E),
    onBrand: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFE6FFFA),
    success: Color(0xFF047857),
    warning: Color(0xFFB45309),
    danger: Color(0xFFB91C1C),
    dangerSoft: Color(0xFFFEF2F2),
  );

  static const dark = IbdPalette(
    bg: Color(0xFF0B1220),
    surface: Color(0xFF151E2E),
    surfaceAlt: Color(0xFF1B2537),
    textPrimary: Color(0xFFE2E8F0),
    textSecondary: Color(0xFF94A3B8),
    outline: Color(0x1FFFFFFF),
    divider: Color(0xFF2A3548),
    brandInk: Color(0xFF5EEAD4),
    onBrand: Color(0xFF0B1220),
    brandSoft: Color(0xFF0F2F2B),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF3A1A1A),
  );

  @override
  IbdPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? outline,
    Color? divider,
    Color? brandInk,
    Color? onBrand,
    Color? brandSoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? dangerSoft,
  }) {
    return IbdPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      outline: outline ?? this.outline,
      divider: divider ?? this.divider,
      brandInk: brandInk ?? this.brandInk,
      onBrand: onBrand ?? this.onBrand,
      brandSoft: brandSoft ?? this.brandSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
    );
  }

  @override
  IbdPalette lerp(ThemeExtension<IbdPalette>? other, double t) {
    if (other is! IbdPalette) return this;
    return IbdPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      brandInk: Color.lerp(brandInk, other.brandInk, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
    );
  }
}

/// 取色入口：`context.ibd.surface` / `context.ibd.textPrimary` …
extension IbdThemeX on BuildContext {
  IbdPalette get ibd =>
      Theme.of(this).extension<IbdPalette>() ?? IbdPalette.light;
}

/// IBDers 视觉规范：冷静医疗绿 + 大留白 + 圆角卡片。
///
/// 对比度（WCAG 2.1 AA，正文需 ≥4.5:1 / 大字号与图形需 ≥3:1，2026-11-10 实测）：
/// - [primary] `#0D9488` 仅作**装饰性填充**（图形、进度条、点）。作文字或按钮底色时
///   白字仅 3.74:1，不达标，改用 [primaryDark] `#0F766E`（5.47:1）。
/// - [textSecondary] `#475569` 在 `bg` 上 7.03:1（原 `#64748B` 仅 4.41:1）。
/// - [success]/[warning]/[danger] 取 700 档，作文字色时均 ≥5:1；
///   原 `#10B981`(2.54) / `#F59E0B`(2.15) / `#EF4444`(3.76) 不达标。
///
/// 注意：这些常量只用于**装饰性**场景与 `const` 上下文；
/// 需要随明暗切换的表面/文字/状态色一律走 [IbdPalette]（`context.ibd.*`）。
class IbdColors {
  static const primary = Color(0xFF0D9488); // teal-600 · 装饰填充
  static const primaryDark = Color(0xFF0F766E); // teal-700 · 按钮/文字（5.47:1）
  static const accent = Color(0xFF14B8A6);
  static const bg = Color(0xFFF4F7F6);
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569); // slate-600 · 7.03:1
  static const success = Color(0xFF047857); // emerald-700 · 5.48:1
  static const warning = Color(0xFFB45309); // amber-700 · 5.02:1
  static const danger = Color(0xFFB91C1C); // red-700 · 6.47:1
  static const chipBg = Color(0xFFE6FFFA);
  static const dangerSoft = Color(0xFFFEF2F2);
}

ThemeData buildIbdTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: IbdColors.primary,
      primary: IbdColors.primary,
      secondary: IbdColors.accent,
      surface: IbdColors.card,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: IbdColors.bg,
    fontFamily: 'PingFang SC',
    extensions: const [IbdPalette.light],
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: IbdColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: IbdColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: IbdColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
      ),
      margin: EdgeInsets.zero,
    ),
    // 按钮宽度分层（U17 已根治）：
    // 这里只给「有限」的最小尺寸（64×48）。全宽主操作请显式包
    // `SizedBox(width: double.infinity, child: ...)`。
    // 历史坑：曾用 `Size.fromHeight(48)`，它等于 `Size(infinity, 48)`，
    // 按钮一旦放进 Row 就会索要无限宽 → 整棵子树布局失败且**静默不绘制**
    // （U14 三页空白页的根因）。不要再把无限尺寸写进主题。
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // 用 primaryDark 而非 primary：白字在 #0D9488 上仅 3.74:1（AA 不达标）
        backgroundColor: IbdColors.primaryDark,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: const BorderSide(color: Color(0xFF94A3B8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: IbdColors.primary, width: 1.6),
      ),
      labelStyle: const TextStyle(color: IbdColors.textSecondary),
    ),
    // Chip 统一观感（U6）：仓库里 ChoiceChip / FilterChip 共 9 处调用，
    // 之前全靠 Material 默认值，圆角、描边、选中色与自定义 chip 都不一致。
    // 这里一次性定死；页面里不要再逐个 styleFrom。
    chipTheme: ChipThemeData(
      backgroundColor: IbdColors.card,
      selectedColor: IbdColors.chipBg,
      disabledColor: IbdColors.bg,
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: IbdColors.textSecondary,
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: IbdColors.primaryDark,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      // 自定义 chip 都没有勾，Material chip 也关掉，避免两套观感
      showCheckmark: false,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: IbdColors.chipBg,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// 深色模式：系统跟随。
ThemeData buildIbdDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: IbdColors.primary,
      primary: const Color(0xFF2DD4BF),
      secondary: IbdColors.accent,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0B1220),
    fontFamily: 'PingFang SC',
    extensions: const [IbdPalette.dark],
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF151E2E),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    // U5：暗色补齐输入框/按钮/底栏三项（原实现只定义了 appBar 与 card，
    // 其余靠 Material 默认值，与浅色主题的圆角、尺寸不一致）
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1B2537),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A3548)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A3548)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF5EEAD4), width: 1.6),
      ),
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: IbdColors.primaryDark,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    // Chip 统一观感（U6）：与浅色同一套几何，只换色值
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1B2537),
      selectedColor: const Color(0xFF0F2F2B),
      disabledColor: const Color(0xFF0B1220),
      side: const BorderSide(color: Color(0xFF2A3548)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF94A3B8),
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF5EEAD4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      showCheckmark: false,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF151E2E),
      indicatorColor: Color(0xFF0F2F2B),
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
