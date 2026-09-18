/// PHQ-9 / 简版 IBDQ / 自定义 QoL 量表规则（仅辅助记录，非诊断）。
class SurveyKit {
  static const phq9Questions = [
    '做事时提不起劲或没有兴趣',
    '感到心情低落、沮丧或绝望',
    '入睡困难、睡不安稳或睡眠过多',
    '感觉疲倦或没有活力',
    '食欲不振或吃太多',
    '觉得自己很糟，或觉得自己很失败',
    '对事物专注有困难',
    '动作或说话速度缓慢，或坐立不安',
    '有不如死掉或用某种方式伤害自己的念头',
  ];

  /// PHQ-9：每题 0–3，总分 0–27
  static String phq9Band(int total) {
    if (total <= 4) return '无或极轻微';
    if (total <= 9) return '轻度';
    if (total <= 14) return '中度';
    if (total <= 19) return '中重度';
    return '重度（建议尽快寻求专业评估）';
  }

  /// 简版 IBDQ 风格：10 题，1–5 分，总分越高越好（10–50）
  static const ibdqQuestions = [
    '过去两周胃肠不适的频率',
    '精力/疲劳感',
    '担心疾病发作',
    '因病请假或无法活动',
    '食欲',
    '睡眠质量',
    '腹痛/腹部不适',
    '社会交往意愿',
    '对治疗有信心',
    '整体生活满意感',
  ];

  static String ibdqBand(int total) {
    if (total >= 40) return '较好';
    if (total >= 30) return '一般';
    return '较差（可与医生讨论）';
  }

  /// 迷你生活质量：5 项 1–5
  static const miniQoLQuestions = [
    '身体状态',
    '情绪状态',
    '社会/家庭支持',
    '工作/学习效率',
    '整体生活质量',
  ];

  static String miniQoLBand(int total) {
    if (total >= 20) return '较好';
    if (total >= 13) return '一般';
    return '较差';
  }

  static String interpret(String kind, int total) {
    switch (kind) {
      case 'PHQ9':
        return phq9Band(total);
      case 'IBDQ':
        return ibdqBand(total);
      case 'MiniQoL':
        return miniQoLBand(total);
      default:
        return '';
    }
  }

  static List<String> questionsFor(String kind) {
    switch (kind) {
      case 'PHQ9':
        return phq9Questions;
      case 'IBDQ':
        return ibdqQuestions;
      default:
        return miniQoLQuestions;
    }
  }
}
