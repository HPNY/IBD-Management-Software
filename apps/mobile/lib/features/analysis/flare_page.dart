import 'package:flutter/material.dart';

import '../../core/flare/flare_service.dart';
import '../../core/ui/theme.dart';

class FlarePage extends StatefulWidget {
  const FlarePage({super.key});

  @override
  State<FlarePage> createState() => _FlarePageState();
}

class _FlarePageState extends State<FlarePage> {
  FlareResult? _result;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final r = await FlareService().assess();
      if (!mounted) return;
      setState(() => _result = r);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _color(FlareLevel l) {
    switch (l) {
      case FlareLevel.red:
        return IbdColors.danger;
      case FlareLevel.yellow:
        return IbdColors.warning;
      case FlareLevel.green:
        return IbdColors.success;
    }
  }

  IconData _icon(FlareLevel l) {
    switch (l) {
      case FlareLevel.red:
        return Icons.emergency_rounded;
      case FlareLevel.yellow:
        return Icons.warning_amber_rounded;
      case FlareLevel.green:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      backgroundColor: IbdColors.bg,
      appBar: AppBar(title: const Text('发作预警')),
      body: _busy && r == null
          ? const Center(child: CircularProgressIndicator())
          : r == null
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _color(r.level),
                            _color(r.level).withValues(alpha: 0.75),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Icon(_icon(r.level), color: Colors.white, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            r.headline,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '依据',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ...r.reasons.map(
                      (e) => Card(
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.radio_button_unchecked_rounded,
                            color: _color(r.level),
                            size: 16,
                          ),
                          title: Text(e),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '建议',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          r.advice,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '本预警基于本机症状与检验记录，不构成医疗诊断。',
                      style: TextStyle(
                        fontSize: 12,
                        color: IbdColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _load,
                      child: Text(_busy ? '评估中…' : '重新评估'),
                    ),
                  ],
                ),
    );
  }
}
