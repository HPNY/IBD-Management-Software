import 'package:flutter/material.dart';

import '../../core/db/repositories.dart';
import 'lab_entry_page.dart';

/// 兼容旧入口：手动录入已并入统一「录入检验」。
class LabManualPage extends StatelessWidget {
  const LabManualPage({super.key, this.labRepo, this.parseFiller});

  final LabRepository? labRepo;
  final LabParseFiller? parseFiller;

  @override
  Widget build(BuildContext context) {
    return LabEntryPage(
      labRepo: labRepo,
      parseFiller: parseFiller,
    );
  }
}
