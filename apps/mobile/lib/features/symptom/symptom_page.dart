import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';

class SymptomPage extends StatefulWidget {
  const SymptomPage({super.key});

  @override
  State<SymptomPage> createState() => _SymptomPageState();
}

class _SymptomPageState extends State<SymptomPage> {
  final _repo = SymptomRepository();
  double _pain = 0;
  int _diarrhea = 0;
  int _stoolType = 4;
  bool _blood = false;
  bool _nausea = false;
  String _feeling = 'same'; // ignore: prefer_final_fields
  bool _saved = false;

  Future<void> _save() async {
    final n = DateTime.now();
    final date =
        '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    await _repo.upsert(
      date: date,
      painLevel: _pain.round(),
      diarrheaCount: _diarrhea,
      stoolType: _stoolType,
      bloodyStool: _blood ? 'obvious' : 'none',
      nausea: _nausea,
      overallFeeling: _feeling,
    );
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('症状日记（本地）')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('腹痛 ${_pain.round()} 分'),
          Slider(
            value: _pain,
            max: 10,
            divisions: 10,
            onChanged: (v) => setState(() {
              _pain = v;
              _saved = false;
            }),
          ),
          Text('腹泻次数 $_diarrhea'),
          Slider(
            value: _diarrhea.toDouble(),
            max: 15,
            divisions: 15,
            onChanged: (v) => setState(() {
              _diarrhea = v.round();
              _saved = false;
            }),
          ),
          Text('Bristol $_stoolType 型'),
          Slider(
            value: _stoolType.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            onChanged: (v) => setState(() {
              _stoolType = v.round();
              _saved = false;
            }),
          ),
          SwitchListTile(
            title: const Text('便血'),
            value: _blood,
            onChanged: (v) => setState(() {
              _blood = v;
              _saved = false;
            }),
          ),
          SwitchListTile(
            title: const Text('恶心'),
            value: _nausea,
            onChanged: (v) => setState(() {
              _nausea = v;
              _saved = false;
            }),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _save,
            child: Text(_saved ? '已保存到本机' : '保存今日打卡'),
          ),
        ],
      ),
    );
  }
}
