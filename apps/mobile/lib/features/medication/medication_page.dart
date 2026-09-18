import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/backup/backup_service.dart';
import '../../core/db/repositories.dart';
import '../../core/identity/local_identity.dart';
import '../../core/ui/theme.dart';
import 'medication_edit_page.dart';

/// C3：用药页与首页网格同风格（卡片 + 统计 + 切换链）
class MedicationPage extends StatefulWidget {
  const MedicationPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<MedicationPage> createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  final _repo = MedicationRepository();
  List<Map<String, dynamic>> _current = [];
  List<Map<String, dynamic>> _all = [];
  bool _busy = false;
  String? _error;
  String? _chainText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final current = await _repo.listCurrent();
      final all = await _repo.listAll();
      final names = all
          .toList()
        ..sort((a, b) =>
            ('${a['start_date']}').compareTo('${b['start_date']}'));
      if (!mounted) return;
      setState(() {
        _current = current;
        _all = all;
        _chainText = names
            .map((m) => '${m['drug_name']}')
            .join('→');
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MedicationEditPage()),
    );
    if (done == true || done == null) await _load();
  }

  Future<void> _stop(Map<String, dynamic> med) async {
    final identity = context.read<LocalIdentity>();
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('停药原因'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: '如：应答不佳 / 副作用 / 换药',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('停用'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    var reason = reasonCtrl.text.trim();
    // C5：敏感原因字段用备份口令加密存储（无口令则明文）
    final pass = await BackupService(identity.uuid).loadPassphrase();
    if (pass != null && reason.isNotEmpty) {
      reason = await encryptSensitiveField(reason, pass, identity.uuid);
    }

    await _repo.stop(med['id'] as String, reason: reason);
    await _load();
  }

  String _routeLabel(String? r) =>
      r == 'oral' ? '口服' : r == 'sc' ? '皮下' : r == 'iv' ? '静脉' : '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('用药管理'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            if ((_chainText ?? '').isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '切换链',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _chainText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              '当前方案（${_current.length}）',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_current.isEmpty)
              _EmptyHint(text: '暂无在用/暂停药物，点右下角新增'),
            ..._current.map((m) => _MedCard(
                  drugName: '${m['drug_name']}',
                  dosage: '${m['dosage']}',
                  meta:
                      '${m['frequency']} · ${_routeLabel(m['route'] as String?)} · 自 ${m['start_date']}',
                  paused: m['status'] == 'paused',
                  reason: m['reason'] as String?,
                  onStop: () => _stop(m),
                  onEdit: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MedicationEditPage(
                          initial: {
                            'id': m['id'],
                            'drugName': m['drug_name'],
                            'brandName': m['brand_name'],
                            'category': m['category'],
                            'dosage': m['dosage'],
                            'frequency': m['frequency'],
                            'route': m['route'],
                            'reason': m['reason'],
                            'startDate': m['start_date'],
                          },
                        ),
                      ),
                    );
                    await _load();
                  },
                )),
            const SizedBox(height: 16),
            const Text(
              '历史时间线',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._all.map((m) {
              final stopped = m['status'] == 'stopped';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: IbdColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      stopped
                          ? Icons.stop_circle_outlined
                          : Icons.medication_rounded,
                      color: stopped
                          ? IbdColors.textSecondary
                          : IbdColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m['drug_name']} ${m['dosage']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${m['start_date']} → ${m['end_date'] ?? '至今'}'
                            ' · ${m['status'] ?? ''}',
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
            }),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(color: IbdColors.danger)),
              ),
          ],
        ),
      ),
    );
  }
}

class _MedCard extends StatelessWidget {
  const _MedCard({
    required this.drugName,
    required this.dosage,
    required this.meta,
    required this.paused,
    required this.reason,
    required this.onStop,
    required this.onEdit,
  });

  final String drugName;
  final String dosage;
  final String meta;
  final bool paused;
  final String? reason;
  final VoidCallback onStop;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IbdColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication_liquid_rounded,
                    color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$drugName $dosage',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 12,
                        color: IbdColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (paused)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: IbdColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('暂停',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: IbdColors.warning)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(onPressed: onEdit, child: const Text('编辑')),
              TextButton(
                onPressed: onStop,
                child: const Text('停药',
                    style: TextStyle(color: IbdColors.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: IbdColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(color: IbdColors.textSecondary)),
    );
  }
}
