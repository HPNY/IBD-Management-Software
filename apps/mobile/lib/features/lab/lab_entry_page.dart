import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_config.dart';
import '../../core/api/ibd_api_client.dart';
import '../../core/api/sync_api.dart';
import '../../core/auth/auth_session.dart';
import '../../core/db/repositories.dart';
import '../../core/identity/local_identity.dart';
import '../../core/lab/lab_panels.dart';
import '../../core/lab/lab_parse_mapper.dart';
import '../../core/skill/local_skill_store.dart';
import '../../core/storage/direct_upload_service.dart';

/// 解析填充：返回规范化的检验项列表（不直接落库）。
typedef LabParseFiller = Future<List<Map<String, dynamic>>> Function({
  required String filename,
  required Uint8List bytes,
  String? hospitalHint,
  String? reportType,
  void Function(String stage)? onProgress,
});

/// 统一「录入检验」：套餐手填 + 报告解析填充，同表单确认后写入本机。
/// 解析服务于录入，不是独立终点。
class LabEntryPage extends StatefulWidget {
  const LabEntryPage({
    super.key,
    this.labRepo,
    this.parseFiller,
    this.emphasizeParse = false,
    this.seedParsedItems,
  });

  final LabRepository? labRepo;

  /// 测试可注入；默认走云端 parse-session。
  final LabParseFiller? parseFiller;

  /// 从「报告解析」入口进入时，突出解析区。
  final bool emphasizeParse;

  /// 测试：预置解析结果，跳过选文件/上传。
  final List<Map<String, dynamic>>? seedParsedItems;

  @override
  State<LabEntryPage> createState() => _LabEntryPageState();
}

class _CustomRow {
  _CustomRow();
  String name = '';
  String value = '';
  String unit = '';
}

class _ParsedItem {
  _ParsedItem({
    required this.nameNorm,
    this.nameRaw,
    required this.valueText,
    required this.unit,
    this.refMin,
    this.refMax,
  }) : ctrl = TextEditingController(text: valueText);

  final String nameNorm;
  final String? nameRaw;
  String valueText;
  final String unit;
  final double? refMin;
  final double? refMax;
  final TextEditingController ctrl;

  /// true：与套餐项同名，值已写入套餐输入框，不在下方重复展示。
  bool matchedPanel = false;

  void dispose() => ctrl.dispose();

  String? flagOf(double value) {
    if (refMax != null && value > refMax!) return 'high';
    if (refMin != null && value < refMin!) return 'low';
    return null;
  }
}

class _LabEntryPageState extends State<LabEntryPage> {
  late final LabRepository _repo = widget.labRepo ?? LabRepository();
  final _dateCtrl = TextEditingController(text: _today());
  final _hospitalCtrl = TextEditingController();
  final _reportTypeCtrl = TextEditingController(text: 'IBD 核心');

  final Set<String> _selectedPanels = {};
  final Map<String, String> _panelValues = {};
  final Map<String, TextEditingController> _panelCtrls = {};
  final List<_ParsedItem> _parsedItems = [];
  final List<_CustomRow> _customRows = <_CustomRow>[];

  String? _fileName;
  Uint8List? _bytes;
  String _stage = 'idle';
  bool _parseUsed = false;
  String? _parseSkillNote;
  bool _busy = false;
  String? _error;
  String? _ok;

  static String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  List<LabItemSpec> get _specs => mergeLabItems(_selectedPanels);

  Set<String> get _panelNames =>
      _specs.map((e) => e.nameNorm).toSet();

  @override
  void initState() {
    super.initState();
    if (!widget.emphasizeParse) {
      _selectedPanels.add('ibd_core');
    }
    final seed = widget.seedParsedItems;
    if (seed != null && seed.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyParsedItems(seed);
      });
    }
  }

  void _applyParsedItems(List<Map<String, dynamic>> items) {
    for (final p in _parsedItems) {
      p.dispose();
    }
    _parsedItems
      ..clear()
      ..addAll(
        items.map(
          (e) => _ParsedItem(
            nameNorm: '${e['nameNorm'] ?? ''}',
            nameRaw: e['nameRaw'] as String?,
            valueText: '${e['valueText'] ?? e['value'] ?? ''}',
            unit: '${e['unit'] ?? ''}',
            refMin: e['refMin'] as double?,
            refMax: e['refMax'] as double?,
          ),
        ),
      );
    _parseUsed = true;
    _stage = items.isEmpty ? 'empty' : 'filled';
    _mergeParsedIntoPanels();
    setState(() {
      _ok = items.isEmpty
          ? '未解析出检验项，可改用套餐手填'
          : '已解析 ${items.length} 项，请核对后保存到本机';
      _error = null;
    });
  }

  TextEditingController _panelCtrl(String nameNorm, String fallback) {
    final existing = _panelCtrls[nameNorm];
    if (existing != null) return existing;
    final c = TextEditingController(text: fallback);
    _panelCtrls[nameNorm] = c;
    return c;
  }

  void _setPanelValue(String nameNorm, String value) {
    _panelValues[nameNorm] = value;
    _panelCtrl(nameNorm, value).text = value;
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _hospitalCtrl.dispose();
    _reportTypeCtrl.dispose();
    for (final c in _panelCtrls.values) {
      c.dispose();
    }
    for (final p in _parsedItems) {
      p.dispose();
    }
    super.dispose();
  }

  void _togglePanel(String id) {
    setState(() {
      if (!_selectedPanels.remove(id)) {
        _selectedPanels.add(id);
      }
      // 取消套餐后，原匹配到套餐的解析项回到下方可编辑列表
      final names = _panelNames;
      for (final p in _parsedItems) {
        if (!p.matchedPanel) continue;
        if (!names.contains(p.nameNorm)) {
          p.matchedPanel = false;
        }
      }
      _ok = null;
      _error = null;
    });
  }

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return;
    setState(() {
      _fileName = file.name;
      _bytes = file.bytes;
    });
  }

  Future<void> _consentAndFill() async {
    final bytes = _bytes;
    final name = _fileName;
    if (bytes == null || name == null) {
      setState(() => _error = '请先选择报告文件');
      return;
    }

    final identity = context.read<LocalIdentity>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认上传解析？'),
        content: Text(
          '解析是为了帮你填写本次检验录入。\n'
          '文件「$name」将上传到服务器解析，结果回到本页，由你确认后再保存。\n'
          '应用标识：${identity.uuid}\n'
          '短时解析会话约 30 分钟；取消则不会上传。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('同意上传并解析'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      setState(() => _stage = 'cancelled');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
      _stage = 'parse_session';
    });

    try {
      final filler = widget.parseFiller ??
          ({
            required String filename,
            required Uint8List bytes,
            String? hospitalHint,
            String? reportType,
            void Function(String stage)? onProgress,
          }) =>
              _cloudParseFill(
                filename: filename,
                bytes: bytes,
                hospitalHint: hospitalHint,
                reportType: reportType,
                onProgress: onProgress,
              );

      final items = await filler(
        filename: name,
        bytes: bytes,
        hospitalHint: _hospitalCtrl.text.trim().isEmpty
            ? null
            : _hospitalCtrl.text.trim(),
        reportType: _reportTypeCtrl.text.trim().isEmpty
            ? null
            : _reportTypeCtrl.text.trim(),
        onProgress: (p) {
          if (mounted) setState(() => _stage = p);
        },
      );

      if (!mounted) return;
      _applyParsedItems(items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<Map<String, dynamic>>> _cloudParseFill({
    required String filename,
    required Uint8List bytes,
    String? hospitalHint,
    String? reportType,
    void Function(String stage)? onProgress,
  }) async {
    final identity = context.read<LocalIdentity>();
    final config = ApiConfig.dev();
    final sessionJson = await SyncApi(config).parseSession(identity.uuid);
    final token = sessionJson['accessToken'] as String;
    final session = AuthSession.parseSession(token, identity.uuid);
    final api = IbdApiClient(config, session);
    try {
      final upload = DirectUploadService(api);
      final job = await upload.uploadAndEnqueue(
        filename: filename,
        bytes: bytes,
        hospitalHint: hospitalHint,
        reportType: reportType,
        onProgress: (p) => onProgress?.call(p.stage),
      );
      final done = await upload.waitUntilDone(job.id);
      return normalizeParseLabItems(done.items);
    } finally {
      api.dispose();
    }
  }

  void _mergeParsedIntoPanels() {
    final specs = _specs;
    final byName = {for (final s in specs) s.nameNorm: s};
    for (final p in _parsedItems) {
      final spec = byName[p.nameNorm];
      if (spec == null) {
        p.matchedPanel = false;
        continue;
      }
      p.matchedPanel = true;
      final v = p.valueText.isNotEmpty
          ? p.valueText
          : (_panelValues[p.nameNorm] ?? '');
      _setPanelValue(p.nameNorm, v);
    }
  }

  Future<void> _save() async {
    final items = <Map<String, dynamic>>[];
    var usedParse = false;
    for (final spec in _specs) {
      final raw =
          _panelCtrl(spec.nameNorm, _panelValues[spec.nameNorm] ?? '')
              .text
              .trim();
      if (raw.isEmpty) continue;
      final value = double.tryParse(raw);
      if (value == null) {
        setState(() => _error = '「${spec.nameNorm}」数值无效');
        return;
      }
      final fromParse = _parsedItems
          .any((p) => p.nameNorm == spec.nameNorm && p.matchedPanel);
      if (fromParse) usedParse = true;
      items.add({
        'nameNorm': spec.nameNorm,
        'nameRaw': spec.nameRaw ?? spec.nameNorm,
        'value': value,
        'unit': spec.unit,
        'refMin': spec.refMin,
        'refMax': spec.refMax,
        'flag': spec.flagOf(value),
      });
    }

    for (final p in _parsedItems) {
      if (p.matchedPanel) continue;
      final raw = p.ctrl.text.trim();
      if (raw.isEmpty) continue;
      final value = double.tryParse(raw);
      if (value == null) {
        setState(() => _error = '「${p.nameNorm}」数值无效');
        return;
      }
      usedParse = true;
      items.add({
        'nameNorm': p.nameNorm,
        'nameRaw': p.nameRaw ?? p.nameNorm,
        'value': value,
        if (p.unit.isNotEmpty) 'unit': p.unit,
        'refMin': p.refMin,
        'refMax': p.refMax,
        'flag': p.flagOf(value),
      });
    }

    for (final row in _customRows) {
      final name = row.name.trim();
      final raw = row.value.trim();
      if (name.isEmpty || raw.isEmpty) continue;
      final value = double.tryParse(raw);
      if (value == null) {
        setState(() => _error = '「$name」数值无效');
        return;
      }
      items.add({
        'nameNorm': name,
        'nameRaw': name,
        'value': value,
        if (row.unit.trim().isNotEmpty) 'unit': row.unit.trim(),
      });
    }

    if (items.isEmpty) {
      setState(() => _error = '请通过套餐或报告解析至少填写一项数值');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    try {
      final hospital = _hospitalCtrl.text.trim();
      final id = await _repo.insert(
        date: _dateCtrl.text.trim(),
        hospital: hospital.isEmpty ? null : hospital,
        source: usedParse && _parseUsed ? 'ai' : 'manual',
        items: items,
      );
      _parseSkillNote = null;
      if (_parseUsed && hospital.isNotEmpty) {
        final reportType = _reportTypeCtrl.text.trim();
        if (reportType.isNotEmpty) {
          await LocalSkillStore.saveFromConfirmed(
            hospital: hospital,
            reportType: reportType,
            items: items,
          );
          _parseSkillNote = '已缓存本地 Skill';
        }
      }
      if (!mounted) return;
      setState(() {
        _ok = '已保存 ${items.length} 项到本机（$id）'
            '${_parseSkillNote == null ? '' : ' · $_parseSkillNote'}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleParsed =
        _parsedItems.where((p) => !p.matchedPanel).toList();
    final filledPanel = _panelValues.values
        .where((v) => v.trim().isNotEmpty)
        .length;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('录入检验')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        controller: ScrollController(),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.merge_type_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '同一录入：可用套餐手填，也可上传报告解析后核对入库。解析只为填表，保存前由你确认。',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dateCtrl,
            decoration: const InputDecoration(
              labelText: '检验日期 YYYY-MM-DD',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hospitalCtrl,
            decoration: const InputDecoration(
              labelText: '医院（可选，解析 Skill 缓存需要）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(
            icon: Icons.document_scanner_rounded,
            title: '报告解析填充（可选）',
            subtitle: '服务录入：解析结果进入本表单，不直接替你保存',
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.privacy_tip_outlined, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '默认不上传；仅点「同意上传并解析」后本次文件才离开本机',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reportTypeCtrl,
                    decoration: const InputDecoration(
                      labelText: '报告类型（用于解析/Skill）',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_fileName ?? '选择报告文件（仍不会上传）'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _consentAndFill,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                      _busy
                          ? '解析中…（$_stage）'
                          : '同意上传解析，结果填入下方',
                    ),
                  ),
                  if (_stage != 'idle' && _stage != 'cancelled')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('阶段：$_stage'),
                    ),
                  if (_parseUsed && _parsedItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '解析 ${_parsedItems.length} 项'
                        '${_parsedItems.any((p) => p.matchedPanel) ? '（已并入同名套餐项）' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(
            icon: Icons.playlist_add_check_rounded,
            title: '检验套餐',
            subtitle: '选大项自动带出小项；解析到同名项会填入这里',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kLabPanels.map((panel) {
              final selected = _selectedPanels.contains(panel.id);
              return FilterChip(
                label: Text(panel.title),
                selected: selected,
                onSelected: (_) => _togglePanel(panel.id),
                avatar: selected ? const Icon(Icons.check, size: 16) : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (_specs.isEmpty)
            Text(
              '未选套餐时，仅保存解析项与自定义项',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else ...[
            Text(
              '套餐小项 · $filledPanel / ${_specs.length} 已填',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ..._specs.map((spec) {
              final controller = _panelCtrl(
                spec.nameNorm,
                _panelValues[spec.nameNorm] ?? '',
              );
              return _ValueRow(
                title: spec.nameNorm,
                subtitle: [
                  if ((spec.nameRaw ?? '').isNotEmpty) spec.nameRaw!,
                  spec.unit,
                  if (spec.displayRef.isNotEmpty) '参考 ${spec.displayRef}',
                ].join(' · '),
                unit: spec.unit,
                controller: controller,
                refMin: spec.refMin,
                refMax: spec.refMax,
                onChanged: (v) => setState(() {
                  _panelValues[spec.nameNorm] = v;
                  _ok = null;
                }),
              );
            }),
          ],
          if (visibleParsed.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionTitle(
              icon: Icons.fact_check_outlined,
              title: '解析待确认项',
              subtitle: '未在当前套餐中，确认数值后一并保存',
            ),
            const SizedBox(height: 8),
            ...visibleParsed.map(
              (p) => _ValueRow(
                title: p.nameNorm,
                subtitle: [
                  if ((p.nameRaw ?? '').isNotEmpty) p.nameRaw!,
                  if (p.unit.isNotEmpty) p.unit,
                  if (p.refMin != null || p.refMax != null)
                    '参考 ${p.refMin != null && p.refMax != null ? '${p.refMin}–${p.refMax}' : p.refMax != null ? '<${p.refMax}' : '>${p.refMin}'}',
                  '来源：报告解析',
                ].join(' · '),
                unit: p.unit,
                controller: p.ctrl,
                refMin: p.refMin,
                refMax: p.refMax,
                onChanged: (v) => setState(() {
                  p.valueText = v;
                  _ok = null;
                }),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text('其他项目（可选）', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._customRows.asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: row.name,
                      decoration: const InputDecoration(
                        labelText: '项目名',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => row.name = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: row.value,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '数值',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => row.value = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: row.unit,
                      decoration: const InputDecoration(
                        labelText: '单位',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => row.unit = v,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _customRows.removeAt(i)),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _customRows.add(_CustomRow())),
            icon: const Icon(Icons.add),
            label: const Text('添加自定义一项'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? '保存中…' : '保存本次检验到本机'),
          ),
          if (_ok != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _ok!,
                style: TextStyle(color: scheme.primary),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.controller,
    required this.refMin,
    required this.refMax,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String unit;
  final TextEditingController controller;
  final double? refMin;
  final double? refMax;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = controller.text;
    final parsed = double.tryParse(value.trim());
    String? flagText;
    Color? flagColor;
    if (parsed != null) {
      if (refMax != null && parsed > refMax!) {
        flagText = '偏高 ↑';
        flagColor = scheme.error;
      } else if (refMin != null && parsed < refMin!) {
        flagText = '偏低 ↓';
        flagColor = Colors.orange.shade800;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (flagText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        flagText,
                        style: TextStyle(
                          color: flagColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: TextFormField(
                key: ValueKey('lab-$title'),
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: '数值',
                  isDense: true,
                  suffixText: unit.isEmpty ? null : unit,
                  border: const OutlineInputBorder(),
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
