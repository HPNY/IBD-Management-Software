import 'package:flutter/material.dart';

import '../../core/ui/cards.dart';
import '../../core/ui/theme.dart';
import 'clinical_pages.dart';
import 'export_page.dart';
import 'flare_page.dart';
import 'food_stool_page.dart';
import 'ai_rules_page.dart';
import 'drug_review_page.dart';
import 'geo_community_page.dart';
import 'my_doctors_page.dart';
import 'survey_page.dart';
import 'annual_report_page.dart';
import 'timeline_page.dart';
import 'trend_page.dart';

/// D：分析 Tab。
///
/// U7（2026-11-13）：原来 14 张平铺卡片按「看趋势 → 看明细 → 拿去给医生看 →
/// 参考与评价」四个使用场景分组。分组不是装饰：用户打开分析 Tab 的目的通常是
/// 其中一种，平铺 14 项时每项平均只有一行可见，找入口反而比分组慢。
/// 「发作预警」并入 AI 分析组（都是"系统替你看"），
/// 「年度报告」并入就诊与报告组（都是"拿去给别人看"），
/// 「食物与排便」并入记录与明细组（与排便细表同一套数据）。
class AnalysisTab extends StatelessWidget {
  const AnalysisTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ibd.bg,
      appBar: AppBar(title: const Text('分析与病程')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const IbdSectionHeader('趋势与时间线'),
          IbdCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.only(bottom: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  _NavRow(
                    icon: Icons.show_chart_rounded,
                    title: '指标趋势',
                    subtitle: 'CRP / 钙卫蛋白等本机检验序列',
                    color: const Color(0xFF0D9488),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrendPage(embedded: false),
                      ),
                    ),
                  ),
                  const _RowDivider(),
                  _NavRow(
                    icon: Icons.timeline_rounded,
                    title: '病程时间线',
                    subtitle: '检验 · 用药 · 注射 · 检查 · 手术',
                    color: const Color(0xFF6366F1),
                    last: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TimelinePage(embedded: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const IbdSectionHeader('记录与明细'),
          IbdCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.only(bottom: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  _NavRow(
                    icon: Icons.monitor_heart_rounded,
                    title: '检查与手术',
                    subtitle: '超声 / 内镜 / 手术记录',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExamPage()),
                    ),
                  ),
                  const _RowDivider(),
                  _NavRow(
                    icon: Icons.wc_rounded,
                    title: '排便细表',
                    subtitle: 'Bristol · 紧迫感 · 便血',
                    color: const Color(0xFFF59E0B),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BathroomPage()),
                    ),
                  ),
                  const _RowDivider(),
                  _NavRow(
                    icon: Icons.restaurant_menu_rounded,
                    title: '食物与排便',
                    subtitle: '食物标签日志 · 腹泻/便血关联观察（G6）',
                    color: const Color(0xFFEA580C),
                    last: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FoodStoolPage()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const IbdSectionHeader('就诊与报告'),
          IbdCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.only(bottom: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  _NavRow(
                    icon: Icons.summarize_rounded,
                    title: '就诊摘要',
                    subtitle: '一键生成门诊汇报文本',
                    color: const Color(0xFF14B8A6),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VisitSummaryPage(),
                      ),
                    ),
                  ),
                  const _RowDivider(),
                  _NavRow(
                    icon: Icons.calendar_month_rounded,
                    title: '年度报告',
                    subtitle: '一年检验 / 用药 / 症状汇总 · 可分享',
                    color: const Color(0xFF10B981),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnnualReportPage(),
                      ),
                    ),
                  ),
                  const _RowDivider(),
                  _NavRow(
                    icon: Icons.medical_services_rounded,
                    title: '我的医生',
                    subtitle: '扫码授权 · 可收回可过期（T6.2）',
                    color: const Color(0xFFB45309),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyDoctorsPage()),
                    ),
                  ),
                  const _RowDivider(),
                  _NavRow(
                    icon: Icons.psychology_alt_rounded,
                    title: '生活质量量表',
                    subtitle: 'PHQ-9 / 简版 IBDQ / SF-36 / MiniQoL',
                    color: const Color(0xFF0EA5E9),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SurveyPage()),
                    ),
                  ),
                  const _RowDivider(),
                  _NavRow(
                    icon: Icons.download_rounded,
                    title: '数据导出',
                    subtitle: '检验 / 用药 / 症状 / 量表 CSV · 本机分享',
                    color: const Color(0xFF64748B),
                    last: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExportPage()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const IbdSectionHeader('分析与参考'),
          IbdCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  _NavRow(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI / 规则分析',
                    subtitle: '趋势方向 · 异常提示 · 用药前后对比（D4）',
                    color: const Color(0xFF7C3AED),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AiRulesPage()),
                    ),
                  ),
                  const _RowDivider(),
                  _NavRow(
                    icon: Icons.warning_amber_rounded,
                    title: '发作预警',
                    subtitle: '便血 / 剧痛 / 连续恶化 · 三级评估',
                    color: const Color(0xFFEF4444),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FlarePage()),
                    ),
                  ),
                  const _RowDivider(),
                  _NavRow(
                    icon: Icons.rate_review_rounded,
                    title: '药物评价',
                    subtitle: '疗效 / 副作用主观评价 · 匿名不含病历（D2）',
                    color: const Color(0xFF0369A1),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DrugReviewPage()),
                    ),
                  ),
                  const _RowDivider(),
                  _NavRow(
                    icon: Icons.location_city_rounded,
                    title: '同城病友 · 就诊指南',
                    subtitle: '昵称 + 城市匿名 · 专科医院参考（D3）',
                    color: const Color(0xFF0F766E),
                    last: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GeoCommunityPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 组内分隔线：用 divider 色，左右各留 14 与图标列对齐。
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 62),
      child: Divider(height: 1, thickness: 1, color: context.ibd.divider),
    );
  }
}

/// 组内一行入口。用 InkWell 而非 Card+ListTile：
/// 外层 IbdCard 已经提供了卡片描边与圆角，再套 Card 会出现双层阴影。
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 10, last ? 12 : 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.ibd.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.ibd.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
