import 'package:flutter/material.dart';

import '../lab/lab_entry_page.dart';

/// 兼容旧「报告解析」入口：解析是录入的一部分，跳转统一录入页。
class ParseUploadPage extends StatelessWidget {
  const ParseUploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LabEntryPage(emphasizeParse: true);
  }
}
