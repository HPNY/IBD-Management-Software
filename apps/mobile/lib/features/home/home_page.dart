import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/identity/local_identity.dart';
import '../injection/injection_page.dart';
import '../lab/lab_manual_page.dart';
import '../medication/medication_page.dart';
import '../parse/parse_upload_page.dart';
import '../symptom/symptom_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<LocalIdentity>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('IBDers'),
        actions: [
          IconButton(
            tooltip: '隐私与同步',
            icon: Icon(
              identity.syncOptIn ? Icons.cloud_queue : Icons.cloud_off,
            ),
            onPressed: () => _showPrivacy(context, identity),
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '数据默认仅保存在本机。未开启同步、未确认上传前，不会把病历发到服务器。',
              style: TextStyle(fontSize: 13),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('手动录入检验'),
            subtitle: const Text('写入本地库'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LabManualPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('上传检验报告解析'),
            subtitle: const Text('上传前需单独确认'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ParseUploadPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.medication),
            title: const Text('用药管理'),
            subtitle: const Text('本地切换链与副作用'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MedicationPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.vaccines),
            title: const Text('注射排期'),
            subtitle: const Text('本地生成 + 本地提醒'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InjectionPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.self_improvement),
            title: const Text('症状日记'),
            subtitle: const Text('今日打卡'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SymptomPage()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacy(BuildContext context, LocalIdentity identity) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('隐私与同步', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('应用标识（本机生成）：\n${identity.uuid}'),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('启用云同步（可选）'),
                subtitle: const Text('开启后才会绑定账号并上传加密副本'),
                value: identity.syncOptIn,
                onChanged: (v) async {
                  await identity.setSyncOptIn(v);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              const Text(
                '说明：关闭同步时，病程数据只在本机；解析上传会在操作时单独询问。',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
