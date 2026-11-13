import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import '../../core/ui/theme.dart';

/// P0-4：检验记录管理（列表 / 编辑日期与医院 / 删除 / 合并重复）。
///
/// 此前只有录入入口，错录后无法修正，也无法删除；同日重复导入只能靠重装。
class LabRecordsPage extends StatefulWidget {
  const LabRecordsPage({super.key});

  @override
  State<LabRecordsPage> createState() => _LabRecordsPageState();
}

class _LabRecordsPageState extends State<LabRecordsPage> {
  final _repo = LabRepository();
  List<Map<String, dynamic>> _labs = [];
  int _dupGroups = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final labs = await _repo.listAll();
    final groups = await _repo.duplicateGroups();
    if (!mounted) return;
    setState(() {
      _labs = labs;
      _dupGroups = groups.length;
      _loading = false;
    });
  }

  Future<void> _edit(Map<String, dynamic> lab) async {
    final dateCtrl = TextEditingController(text: '${lab['date']}');
    final hospCtrl = TextEditingController(text: '${lab['hospital'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑检验记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dateCtrl,
              decoration: const InputDecoration(
                labelText: '日期（YYYY-MM-DD）',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: hospCtrl,
              decoration: const InputDecoration(labelText: '医院（可空）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final date = dateCtrl.text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日期格式应为 YYYY-MM-DD')),
      );
      return;
    }
    await _repo.updateMeta(
      '${lab['id']}',
      date: date,
      hospital: hospCtrl.text.trim().isEmpty ? null : hospCtrl.text.trim(),
    );
    await _load();
  }

  Future<void> _delete(Map<String, dynamic> lab) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这份检验记录？'),
        content: Text(
          '${lab['date']} · ${lab['hospital'] ?? '未填医院'} · '
          '${(lab['items'] as List).length} 项\n删除后不可恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.delete('${lab['id']}');
    await _load();
  }

  Future<void> _mergeDuplicates() async {
    final groups = await _repo.duplicateGroups();
    if (groups.isEmpty || !mounted) return;
    final extra = groups.fold<int>(0, (a, g) => a + g.length - 1);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('合并重复记录？'),
        content: Text('发现 $_dupGroups 组重复，将保留每组最早一份，删除其余 $extra 份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('合并'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final g in groups) {
      // 保留 created_at 最早的一条
      final sorted = [...g]..sort((a, b) => '${a['created_at'] ?? ''}'
          .compareTo('${b['created_at'] ?? ''}'));
      for (final lab in sorted.skip(1)) {
        await _repo.delete('${lab['id']}');
      }
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ibd.bg,
      appBar: AppBar(
        title: const Text('检验记录'),
        actions: [
          IconButton(
            tooltip: '合并重复',
            onPressed: _dupGroups == 0 ? null : _mergeDuplicates,
            icon: Badge(
              isLabelVisible: _dupGroups > 0,
              label: Text('$_dupGroups'),
              child: const Icon(Icons.merge_type_rounded),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _labs.isEmpty
              ? Center(
                  child: Text(
                    '还没有检验记录。\n可在首页「检验录入」添加，或从报告解析导入。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.ibd.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _labs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final lab = _labs[i];
                    final items = (lab['items'] as List).length;
                    return Card(
                      child: ListTile(
                        title: Text(
                          '${lab['date']} · ${lab['hospital'] ?? '未填医院'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '$items 项 · 来源 ${lab['source'] ?? 'manual'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '编辑',
                              onPressed: () => _edit(lab),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: '删除',
                              onPressed: () => _delete(lab),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
