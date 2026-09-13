import 'package:flutter/material.dart';

import 'features/parse/parse_upload_page.dart';

void main() {
  runApp(const IbdApp());
}

class IbdApp extends StatelessWidget {
  const IbdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '肠安通',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('肠安通')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('上传检验报告'),
            subtitle: const Text('直传 Object Storage → BullMQ 解析'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ParseUploadPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
