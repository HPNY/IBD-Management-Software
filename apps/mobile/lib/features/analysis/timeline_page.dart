import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/ui/theme.dart';
import 'clinical_pages.dart';

/// D2：本机病程时间线
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key, this.embedded = true});

  final bool embedded;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  final _repo = TimelineRepository();
  List<Map<String, dynamic>> _events = [];
  String? _filter;

  static const filters = <String?, String>{
    null: '全部',
    'lab': '检验',
    'med': '用药',
    'inj': '注射',
    'exam': '检查',
    'surgery': '手术',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _repo.events(limit: 300);
    if (!mounted) return;
    setState(() {
      _events = all.where((e) {
        if (_filter == null) return true;
        final t = '${e['type']}';
        return t.startsWith(_filter!) || t.contains(_filter!);
      }).toList();
    });
  }

  IconData _icon(String type) {
    switch (type) {
      case 'lab':
        return Icons.biotech_rounded;
      case 'med':
        return Icons.medication_rounded;
      case 'med_end':
        return Icons.stop_circle_outlined;
      case 'inj_done':
        return Icons.vaccines_rounded;
      case 'inj_plan':
        return Icons.schedule_rounded;
      case 'exam':
        return Icons.monitor_heart_rounded;
      case 'surgery':
        return Icons.local_hospital_rounded;
      default:
        return Icons.circle;
    }
  }

  Color _color(String type) {
    if (type.startsWith('inj')) return const Color(0xFF8B5CF6);
    if (type.startsWith('med')) return const Color(0xFFF59E0B);
    if (type == 'lab') return IbdColors.primary;
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('病程时间线'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamPage()),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: '检查/手术',
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: filters.entries.map((e) {
                final sel = e.key == _filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: sel,
                    onSelected: (_) {
                      setState(() => _filter = e.key);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _events.isEmpty
                ? const Center(
                    child: Text(
                      '暂无病程事件\n录入检验/用药/注射/检查后自动生成',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: IbdColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: _events.length,
                    itemBuilder: (context, i) {
                      final e = _events[i];
                      final type = '${e['type']}';
                      final color = _color(type);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_icon(type), color: color, size: 18),
                              ),
                              if (i != _events.length - 1)
                                Container(
                                  width: 2,
                                  height: 36,
                                  color: const Color(0xFFE2E8F0),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: IbdColors.card,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e['date']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: IbdColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${e['title']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if ('${e['subtitle'] ?? ''}'.trim().isNotEmpty)
                                    Text(
                                      '${e['subtitle']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: IbdColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
