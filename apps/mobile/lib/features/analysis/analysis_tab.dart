import 'package:flutter/material.dart';

import '../../core/ui/theme.dart';
import 'clinical_pages.dart';
import 'export_page.dart';
import 'flare_page.dart';
import 'survey_page.dart';
import 'timeline_page.dart';
import 'trend_page.dart';

/// D：分析 Tab（趋势 / 时间线 / 检查手术 / 排便 / 就诊摘要）
class AnalysisTab extends StatelessWidget {
  const AnalysisTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(title: const Text('分析与病程')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _NavCard(
            icon: Icons.show_chart_rounded,
            title: '指标趋势',
            subtitle: 'CRP / 钙卫蛋白等本机检验序列',
            color: const Color(0xFF0D9488),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrendPage(embedded: false)),
            ),
          ),
          _NavCard(
            icon: Icons.timeline_rounded,
            title: '病程时间线',
            subtitle: '检验 · 用药 · 注射 · 检查 · 手术',
            color: const Color(0xFF6366F1),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TimelinePage(embedded: false)),
            ),
          ),
          _NavCard(
            icon: Icons.monitor_heart_rounded,
            title: '检查与手术',
            subtitle: '超声/内镜/手术记录',
            color: const Color(0xFF8B5CF6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamPage()),
            ),
          ),
          _NavCard(
            icon: Icons.wc_rounded,
            title: '排便细表',
            subtitle: 'Bristol · 紧迫感 · 便血',
            color: const Color(0xFFF59E0B),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BathroomPage()),
            ),
          ),
          _NavCard(
            icon: Icons.summarize_rounded,
            title: '就诊摘要',
            subtitle: '一键生成门诊汇报文本',
            color: const Color(0xFF14B8A6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VisitSummaryPage()),
            ),
          ),
          _NavCard(
            icon: Icons.warning_amber_rounded,
            title: '发作预警',
            subtitle: '便血/剧痛/连续恶化 · 三级评估',
            color: const Color(0xFFEF4444),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FlarePage()),
            ),
          ),
          _NavCard(
            icon: Icons.psychology_alt_rounded,
            title: '生活质量量表',
            subtitle: 'PHQ-9 / 简版 IBDQ / MiniQoL',
            color: const Color(0xFF0EA5E9),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SurveyPage()),
            ),
          ),
          _NavCard(
            icon: Icons.download_rounded,
            title: '数据导出',
            subtitle: '检验/用药/症状/量表 CSV · 本机分享',
            color: const Color(0xFF64748B),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExportPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: IbdColors.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: IbdColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: IbdColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
