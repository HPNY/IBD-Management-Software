/// 量表题目：专业条目 + 通俗解释 + 选项文案（降低理解成本）。
class SurveyKit {
  /// PHQ-9：过去两周，下列情况出现的频率
  static const phq9Questions = [
    SurveyQuestion(
      text: '做事时提不起劲或没有兴趣',
      hint: '例如：以前喜欢的事现在懒得做，家务/上班提不起精神',
    ),
    SurveyQuestion(
      text: '感到心情低落、沮丧或绝望',
      hint: '例如：心里难受、觉得灰暗、看不到好转',
    ),
    SurveyQuestion(
      text: '入睡困难、睡不安稳或睡眠过多',
      hint: '例如：躺下很久睡不着、半夜常醒，或整天想睡',
    ),
    SurveyQuestion(
      text: '感觉疲倦或没有活力',
      hint: '例如：稍微活动就累，整天没劲',
    ),
    SurveyQuestion(
      text: '食欲不振或吃太多',
      hint: '例如：不想吃饭，或控制不住吃很多',
    ),
    SurveyQuestion(
      text: '觉得自己很糟，或觉得自己很失败',
      hint: '例如：总觉得对不起家人、什么都做不好',
    ),
    SurveyQuestion(
      text: '对事物专注有困难',
      hint: '例如：看书、开会、算账时走神',
    ),
    SurveyQuestion(
      text: '动作或说话速度缓慢，或坐立不安',
      hint: '例如：反应变慢，或静不下来、来回踱步',
    ),
    SurveyQuestion(
      text: '有不如死掉或用某种方式伤害自己的念头',
      hint: '若选「一半以上」请尽快联系家人或就医；本应用不能替代急救',
    ),
  ];

  /// PHQ-9 选项：0–3
  static const phq9Options = [
    SurveyOption(0, '完全没有', '几乎没有这种情况'),
    SurveyOption(1, '有几天', '偶尔出现，不是天天'),
    SurveyOption(2, '一半以上天数', '差不多隔天或更常'),
    SurveyOption(3, '几乎每天', '天天都有'),
  ];

  /// 简版 IBDQ：分数越高越好
  static const ibdqQuestions = [
    SurveyQuestion(
      text: '胃肠不适的频率',
      hint: '肚子痛、胀、急着上厕所等，越少越好（越少越接近 5 分）',
    ),
    SurveyQuestion(
      text: '精力 / 疲劳感',
      hint: '精力越充足分越高；整天没劲则分低',
    ),
    SurveyQuestion(
      text: '担心疾病发作',
      hint: '越不担心分越高；总怕突然不舒服则分低',
    ),
    SurveyQuestion(
      text: '因病影响日常活动',
      hint: '越不影响工作/生活分越高；经常被迫停下则分低',
    ),
    SurveyQuestion(
      text: '食欲',
      hint: '想吃饭、能吃下 → 分高；没胃口 → 分低',
    ),
    SurveyQuestion(
      text: '睡眠质量',
      hint: '睡得踏实 → 分高；总醒、难入睡 → 分低',
    ),
    SurveyQuestion(
      text: '腹痛/腹部不适',
      hint: '几乎不痛 → 分高；经常疼 → 分低',
    ),
    SurveyQuestion(
      text: '社会交往意愿',
      hint: '愿意出门见人 → 分高；躲着不想见人 → 分低',
    ),
    SurveyQuestion(
      text: '对治疗有信心',
      hint: '越有信心分越高',
    ),
    SurveyQuestion(
      text: '整体生活满意感',
      hint: '对自己近两周生活越满意分越高',
    ),
  ];

  static const ibdqOptions = [
    SurveyOption(1, '很差 / 总是', '几乎每天都不舒服或受影响'),
    SurveyOption(2, '较差 / 常常', '一周大半时间如此'),
    SurveyOption(3, '一般 / 有时', '有好有坏'),
    SurveyOption(4, '较好 / 偶尔', '多数时候还行'),
    SurveyOption(5, '很好 / 几乎没有', '几乎不受影响'),
  ];

  static const miniQoLQuestions = [
    SurveyQuestion(text: '身体状态', hint: '疼痛、体力、胃肠感觉综合打分'),
    SurveyQuestion(text: '情绪状态', hint: '开心、平静 vs 烦躁、低落'),
    SurveyQuestion(text: '社会/家庭支持', hint: '身边人是否理解、愿意帮忙'),
    SurveyQuestion(text: '工作/学习效率', hint: '能否完成平时该做的事'),
    SurveyQuestion(text: '整体生活质量', hint: '若给最近生活打一个总分'),
  ];

  static const miniQoLOptions = [
    SurveyOption(1, '很差', '几乎天天难受'),
    SurveyOption(2, '较差', '多数时间不舒服'),
    SurveyOption(3, '一般', '还能应付'),
    SurveyOption(4, '较好', '多数时候不错'),
    SurveyOption(5, '很好', '基本和生病前差不多'),
  ];

  static String phq9Band(int total) {
    if (total <= 4) return '无或极轻微';
    if (total <= 9) return '轻度';
    if (total <= 14) return '中度';
    if (total <= 19) return '中重度';
    return '重度（建议尽快寻求专业评估）';
  }

  static String ibdqBand(int total) {
    if (total >= 40) return '较好';
    if (total >= 30) return '一般';
    return '较差（可与医生讨论）';
  }

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
      default:
        return miniQoLBand(total);
    }
  }

  static List<SurveyQuestion> questionsFor(String kind) {
    switch (kind) {
      case 'PHQ9':
        return phq9Questions;
      case 'IBDQ':
        return ibdqQuestions;
      default:
        return miniQoLQuestions;
    }
  }

  static List<SurveyOption> optionsFor(String kind) {
    switch (kind) {
      case 'PHQ9':
        return phq9Options;
      case 'IBDQ':
        return ibdqOptions;
      default:
        return miniQoLOptions;
    }
  }

  /// 量表说明（选前阅读）
  static String introFor(String kind) {
    switch (kind) {
      case 'PHQ9':
        return '请回忆「最近两周」。按出现的频率选一个最接近的即可，没有对错。'
            '这是情绪健康自查，不能替代医生诊断。';
      case 'IBDQ':
        return '请回忆「最近两周」肠病对生活的影响。分数越高表示状态越好。'
            '若某项说不清，选「一般」即可。';
      default:
        return '快速给最近的整体状态打分（1–5），约 30 秒完成。';
    }
  }

  /// 每题答题提示（滑块/选项旁）
  static String hintText(String kind, int index) {
    final qs = questionsFor(kind);
    if (index < 0 || index >= qs.length) return '';
    return qs[index].hint;
  }

  static String questionText(String kind, int index) {
    final qs = questionsFor(kind);
    return qs[index].text;
  }

  static int maxScore(String kind) => kind == 'PHQ9' ? 3 : 4;

  /// 中文题名（避免用户只看到英文代号）
  static String kindTitle(String kind) {
    switch (kind) {
      case 'PHQ9':
        return 'PHQ-9 · 情绪自查';
      case 'IBDQ':
        return '简版 IBDQ · 肠病生活质量';
      default:
        return 'Mini QoL · 快速生活评分';
    }
  }

  /// 某分值对应的通俗选项文案
  static String optionLabel(String kind, int score) {
    final opts = optionsFor(kind);
    for (final o in opts) {
      if (o.value == score) return o.label;
    }
    return '$score 分';
  }
}

class SurveyQuestion {
  const SurveyQuestion({required this.text, required this.hint});
  final String text;
  final String hint;
}

class SurveyOption {
  const SurveyOption(this.value, this.label, this.detail);
  final int value;
  final String label;
  final String detail;
}
