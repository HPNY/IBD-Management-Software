import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/repositories.dart';
import '../../core/identity/local_identity.dart';
import '../../core/ui/theme.dart';
import '../analysis/trend_page.dart';
import '../lab/lab_entry_page.dart';
import '../medication/medication_page.dart';

/// 首页 Tab：仪表盘 + 快捷入口（不负责底部导航壳）
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.onOpen});

  /// 0 打卡 2 注射 —— 用于底部切 Tab
  final void Function(int index) onOpen;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _inj = InjectionRepository();
  final _labs = LabRepository();
  final _meds = MedicationRepository();
  final _symptoms = SymptomRepository();
  List<Map<String, dynamic>> _dueInj = [];
  int _labCount = 0;
  int _medCount = 0;
  bool _symptomToday = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final due = await _inj.listPending(withinDays: 7);
      final labs = await _labs.listAll();
      final meds = await _meds.listCurrent();
      final symptoms = await _symptoms.listAll();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (!mounted) return;
      setState(() {
        _dueInj = due;
        _labCount = labs.length;
        _medCount = meds.length;
        _symptomToday = symptoms.any((s) => '${s['date']}' == today);
      });
    } catch (_) {}
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 11) return '早上好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<LocalIdentity>();
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Header(
              greeting: _greeting,
              onSettings: () => widget.onOpen(3),
            ),
            _PrivacyBanner(syncOn: identity.syncOptIn),
            _TodayCard(
              symptomDone: _symptomToday,
              dueInjections: _dueInj.length,
              onSymptom: () => widget.onOpen(1),
              onInjection: () => widget.onOpen(2),
            ),
            const IbdSectionTitle('快捷入口'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _ModuleCard(
                    icon: Icons.biotech_rounded,
                    title: '录入检验',
                    subtitle: '套餐手填 · 报告解析入库',
                    color: const Color(0xFF0D9488),
                    onTap: () => _push(const LabEntryPage()),
                  ),
                  _ModuleCard(
                    icon: Icons.show_chart_rounded,
                    title: '指标趋势',
                    subtitle: 'CRP / 钙卫蛋白等',
                    color: const Color(0xFF6366F1),
                    onTap: () => _push(const TrendPage(embedded: false)),
                  ),
                  _ModuleCard(
                    icon: Icons.medication_liquid_rounded,
                    title: '用药管理',
                    subtitle: '$_medCount 项在用/暂停',
                    color: const Color(0xFFF59E0B),
                    onTap: () => _push(const MedicationPage()),
                  ),
                  _ModuleCard(
                    icon: Icons.vaccines_rounded,
                    title: '注射排期',
                    subtitle:
                        _dueInj.isEmpty ? '本地提醒' : '${_dueInj.length} 针待处理',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => widget.onOpen(2),
                  ),
                ],
              ),
            ),
            const IbdSectionTitle('本机数据'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: '检验记录',
                      value: '$_labCount',
                      icon: Icons.biotech_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatChip(
                      label: '应用标识',
                      value: identity.uuid.substring(0, 8),
                      icon: Icons.fingerprint_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.onSettings,
  });

  final String greeting;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 14,
                    color: IbdColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'IBDers',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: IbdColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onSettings,
            tooltip: '我的与设置',
            icon: const Icon(Icons.settings_rounded),
            style: IconButton.styleFrom(
              backgroundColor: IbdColors.chipBg,
              foregroundColor: IbdColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner({required this.syncOn});
  final bool syncOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IbdColors.chipBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            syncOn ? Icons.cloud_done_rounded : Icons.shield_moon_rounded,
            color: IbdColors.primaryDark,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              syncOn ? '已开启云同步（密文备份）' : '数据仅存本机，未授权不上传',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: IbdColors.primaryDark,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.symptomDone,
    required this.dueInjections,
    required this.onSymptom,
    required this.onInjection,
  });

  final bool symptomDone;
  final int dueInjections;
  final VoidCallback onSymptom;
  final VoidCallback onInjection;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日管理',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            symptomDone ? '症状已打卡 · 很好' : '记得完成今日症状打卡',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TodayAction(
                  label: symptomDone ? '修改打卡' : '症状打卡',
                  icon: Icons.favorite_rounded,
                  onTap: onSymptom,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TodayAction(
                  label: dueInjections > 0 ? '注射 $dueInjections' : '注射排期',
                  icon: Icons.vaccines_rounded,
                  filled: dueInjections > 0,
                  onTap: onInjection,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayAction extends StatelessWidget {
  const _TodayAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.white.withOpacity(0.16),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: filled ? IbdColors.primary : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled ? IbdColors.primary : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
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
    return Material(
      color: IbdColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: IbdColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IbdColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, color: IbdColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: IbdColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
