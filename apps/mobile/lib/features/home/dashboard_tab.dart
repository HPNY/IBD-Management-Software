import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/activity/activity_service.dart';
import '../../core/db/repositories.dart';
import '../../core/identity/local_identity.dart';
import '../../core/ui/accessibility.dart';
import '../../core/ui/cards.dart';
import '../../core/ui/theme.dart';
import '../analysis/trend_page.dart';
import '../lab/lab_entry_page.dart';
import '../medication/medication_page.dart';
import '../shell_page.dart';
import 'activity_detail_page.dart';

/// 首页 Tab：仪表盘 + 快捷入口（不负责底部导航壳）
class DashboardTab extends StatefulWidget {
  const DashboardTab({
    super.key,
    required this.onOpen,
    this.injRepo,
    this.labRepo,
    this.medRepo,
    this.symptomRepo,
  });

  /// 跳转到 Shell 底部 Tab，索引见 [ShellTabs]。
  final void Function(int index) onOpen;

  /// 测试可注入仓库；生产默认本机 LocalDb。
  final InjectionRepository? injRepo;
  final LabRepository? labRepo;
  final MedicationRepository? medRepo;
  final SymptomRepository? symptomRepo;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late final _inj = widget.injRepo ?? InjectionRepository();
  late final _labs = widget.labRepo ?? LabRepository();
  late final _meds = widget.medRepo ?? MedicationRepository();
  late final _symptoms = widget.symptomRepo ?? SymptomRepository();
  List<Map<String, dynamic>> _dueInj = [];
  int _labCount = 0;
  int _medCount = 0;
  bool _symptomToday = false;

  // G1 疾病活动度卡
  List<Map<String, dynamic>> _labRows = [];
  List<Map<String, dynamic>> _medsNow = [];
  String _countdownLabel = '—';
  bool _countdownWarn = false;

  /// 本机数据读取失败提示。非空时首页必须显式告知，
  /// 不得把读取失败静默渲染成"0 条记录 / 无待打针"（U1）。
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // 快捷入口「注射 N」保持原 7 天窗口；活动度倒计时单独查 60 天。
      final dueSoon = await _inj.listPending(withinDays: 7);
      final dueWide = await _inj.listPending(withinDays: 60);
      final labs = await _labs.listAll();
      final meds = await _meds.listCurrent();
      final symptoms = await _symptoms.listAll();
      final today = DateTime.now().toIso8601String().substring(0, 10);

      final sortedDue = [...dueWide]
        ..sort((a, b) =>
            '${a['planned_date']}'.compareTo('${b['planned_date']}'));
      final days = sortedDue.isEmpty
          ? null
          : daysUntilInjection('${sortedDue.first['planned_date']}');
      final countdown = days == null
          ? '无待打针'
          : days < 0
              ? '逾期 ${-days} 天'
              : days == 0
                  ? '今天该打'
                  : '$days 天';

      if (!mounted) return;
      setState(() {
        _dueInj = dueSoon;
        _labCount = labs.length;
        _medCount = meds.length;
        _symptomToday = symptoms.any((s) => '${s['date']}' == today);
        _labRows = labs;
        _medsNow = meds;
        _countdownLabel = countdown;
        _countdownWarn = days != null && days <= 3;
        _loadError = null;
      });
    } catch (_) {
      // 读取失败必须可见：静默保持 0 会让患者误判为"没有异常/没有待办"
      if (!mounted) return;
      setState(() => _loadError = '本机数据读取失败，以下数字可能不是最新');
    }
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

  ({String label, String state, IbdMetricTone tone}) _trioSpot(
    String nameNorm,
    String label,
  ) {
    final item = latestLabItem(_labRows, nameNorm);
    final light = item == null ? 'gray' : inflammationLight(item['flag'] as String?);
    // 状态词与档位都由领域层的灯态推导，页面不再各自映射颜色
    return (
      label: label,
      state: inflammationStateText(light),
      tone: IbdMetricTone.ofLight(light),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<LocalIdentity>();
    final simple = context.watch<AccessibilityPrefs>().simpleMode;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Header(
              greeting: _greeting,
              onSettings: () => widget.onOpen(ShellTabs.me),
            ),
            if (!simple) _PrivacyBanner(syncOn: identity.syncOptIn),
            if (_loadError != null)
              _LoadErrorBanner(message: _loadError!, onRetry: _loadStats),
            _TodayCard(
              symptomDone: _symptomToday,
              dueInjections: _dueInj.length,
              onSymptom: () => widget.onOpen(ShellTabs.checkIn),
              onInjection: () => widget.onOpen(ShellTabs.injection),
            ),
            // G1：疾病活动度卡（PRD §2.6.1）
            _ActivityCard(
              lights: [
                _trioSpot('超敏C反应蛋白', 'CRP'),
                _trioSpot('血沉', 'ESR'),
                _trioSpot('粪便钙卫蛋白', '钙卫'),
              ],
              countdown: _countdownLabel,
              countdownWarn: _countdownWarn,
              medSummary: _medsNow.isEmpty
                  ? ''
                  : _medsNow.length <= 2
                      ? _medsNow
                          .map(
                            (m) =>
                                '${(m['drugName'] ?? m['drug_name']) ?? ''} ${m['dosage'] ?? ''}',
                          )
                          .join(' · ')
                      : '${_medsNow[0]['drugName'] ?? _medsNow[0]['drug_name'] ?? ''} · '
                          '${_medsNow[1]['drugName'] ?? _medsNow[1]['drug_name'] ?? ''} 等 ${_medsNow.length} 项',
              onTap: () => _push(const ActivityDetailPage()),
            ),
            // 简洁模式：只留「今日待办 + 疾病活动度」两块。
            // 原实现只藏了一条隐私横幅，等于没生效——用户开了简洁模式，
            // 首屏还是一模一样（U8 真机走查发现）。
            if (!simple) ...[
              const IbdSectionHeader('快捷入口'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                // 原为 GridView + childAspectRatio: 1.15：高度被宽度锁死，
                // 每张卡约 156dp，图标与文字被 spaceBetween 拉开，第二行还会被
                // 视口切成半截；大字体模式下文字更会溢出。
                // 改为按内容定高 + IntrinsicHeight 对齐同一行两张卡的高度。
                child: Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _ModuleCard(
                              icon: Icons.biotech_rounded,
                              title: '录入检验',
                              subtitle: '套餐手填 · 报告解析入库',
                              color: const Color(0xFF0D9488),
                              onTap: () => _push(const LabEntryPage()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ModuleCard(
                              icon: Icons.show_chart_rounded,
                              title: '指标趋势',
                              subtitle: 'CRP / 钙卫蛋白等',
                              color: const Color(0xFF6366F1),
                              onTap: () => _push(const TrendPage(embedded: false)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _ModuleCard(
                              icon: Icons.medication_liquid_rounded,
                              title: '用药管理',
                              subtitle: '$_medCount 项在用/暂停',
                              color: const Color(0xFFF59E0B),
                              onTap: () => _push(const MedicationPage()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ModuleCard(
                              icon: Icons.vaccines_rounded,
                              title: '注射排期',
                              subtitle: _dueInj.isEmpty
                                  ? '本地提醒'
                                  : '${_dueInj.length} 针待处理',
                              color: const Color(0xFF8B5CF6),
                              onTap: () => widget.onOpen(ShellTabs.injection),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const IbdSectionHeader('本机数据'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      // IbdMetric 只管指标内容，卡片容器由 IbdCard 提供
                      child: IbdCard(
                        radius: 18,
                        child: IbdMetric.stat(
                          label: '检验记录',
                          value: '$_labCount',
                          icon: Icons.biotech_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: IbdCard(
                        radius: 18,
                        child: IbdMetric.stat(
                          label: '应用标识',
                          value: identity.uuid.substring(0, 8),
                          icon: Icons.fingerprint_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // 简洁模式下只剩两块，下方大片空白容易被误认为「页面坏了」。
            // 给一句说明 + 出口，比留白更让人安心。
            if (simple)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  '简洁模式已开启 · 只显示今日待办与活动度，可在「我的 → 可用性」关闭',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: context.ibd.textSecondary,
                  ),
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
                  style: TextStyle(
                    fontSize: 14,
                    color: context.ibd.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'IBDers',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: context.ibd.textPrimary,
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
              backgroundColor: context.ibd.brandSoft,
              foregroundColor: context.ibd.brandInk,
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
        color: context.ibd.brandSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            syncOn ? Icons.cloud_done_rounded : Icons.shield_moon_rounded,
            color: context.ibd.brandInk,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              syncOn ? '已开启云同步（密文备份）' : '数据仅存本机，未授权不上传',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.ibd.brandInk,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 本机数据读取失败条：明确告知 + 一键重试（替代原先的静默吞错）。
class _LoadErrorBanner extends StatelessWidget {
  const _LoadErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: context.ibd.dangerSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.ibd.danger.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: context.ibd.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: context.ibd.danger,
              ),
            ),
          ),
          TextButton(
            onPressed: () => onRetry(),
            style: TextButton.styleFrom(
              foregroundColor: context.ibd.danger,
              minimumSize: const Size(56, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('重试', style: TextStyle(fontWeight: FontWeight.w700)),
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
        // 深一档的渐变：白字在 #0D9488/#14B8A6 上仅 3.74/2.46:1，AA 不达标
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
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
            style: TextStyle(color: Colors.white, fontSize: 13),
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
    // 主按钮在明暗下取不同的"底/字"组合：
    // 浅色 = 白底 + 深青字（5.47:1）；暗色 = 亮青底 + 深底字（≈11:1）。
    // 若沿用"白底 + brandInk 字"，暗色下 brandInk 是亮青，压白底几乎不可读。
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filledBg = isDark ? context.ibd.brandInk : Colors.white;
    final filledFg = isDark ? context.ibd.bg : context.ibd.brandInk;
    return Material(
      // 次按钮用"压暗"而非"提亮"：白色半透明叠在深绿上会拉低白字对比度
      color: filled ? filledBg : Colors.black.withValues(alpha: 0.16),
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
                color: filled ? filledFg : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled ? filledFg : Colors.white,
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

/// G1 首页疾病活动度卡：三联状态灯 + 注射倒计时 + 用药摘要。
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.lights,
    required this.countdown,
    required this.countdownWarn,
    required this.medSummary,
    required this.onTap,
  });

  final List<({String label, String state, IbdMetricTone tone})> lights;
  final String countdown;
  final bool countdownWarn;
  final String medSummary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.ibd.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.ibd.outline),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '疾病活动度',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '详情 ›',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.ibd.brandInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final t in lights)
                    Expanded(
                      child: IbdMetric.status(
                        label: t.label,
                        state: t.state,
                        tone: t.tone,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.vaccines_rounded,
                    size: 16,
                    color: countdownWarn
                        ? context.ibd.warning
                        : IbdColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '注射倒计时 $countdown',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: countdownWarn
                          ? context.ibd.warning
                          : context.ibd.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // 无在用药物时不渲染摘要：既没有信息量，
                  // 在大字体下还会被省略号截成「暂无在用…」
                  if (medSummary.isNotEmpty)
                    Flexible(
                      child: Text(
                        medSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.ibd.textSecondary,
                        ),
                      ),
                    ),
                ],
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
    // U6：卡片骨架统一走 IbdCard，这里只描述内容
    return IbdCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                style: TextStyle(
                  fontSize: 12,
                  color: context.ibd.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
