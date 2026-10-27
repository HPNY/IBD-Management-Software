import 'package:flutter/material.dart';

import 'theme.dart';

/// T7：非诊断/非治疗声明（约束 §6：合规文案明确"非诊断、非治疗建议"）。
///
/// 置于解读类页面（分析/预警/评价/关联/活动度）底部常驻可见。
const kNonMedicalDisclaimer =
    '本页内容为自我管理记录与统计观察，非诊断、非治疗建议；'
    '用药、复查与治疗决策请遵医嘱';

class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        kNonMedicalDisclaimer,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: IbdColors.textSecondary),
      ),
    );
  }
}
