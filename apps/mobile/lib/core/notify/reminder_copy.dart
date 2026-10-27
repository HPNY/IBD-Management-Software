/// T6：提醒通知通用文案（脱敏）。
///
/// 约束 §6 + T6 验收「通知内容不含敏感病历信息」：所有本地/远程提醒文案
/// 不得包含药名、剂量、检验值、诊断等病历字段；仅通用指引语。
/// 通用性由 `reminder_copy_test` 的禁词表断言固化。
library;

/// 注射提醒（提前档）：不含药名/剂量/日期明细
const kInjectionReminderBody =
    '您有 1 项注射计划临近，请打开 IBDers 查看排期详情';

/// 注射当天：证件/医保卡提示（PRD §2.5.1），通用语
const kInjectionTodayBody =
    '今天有注射计划：请按计划就诊，并记得携带证件与医保卡；详情请打开 IBDers';

/// 用药提醒（每日重复）：不写具体药物
const kMedicationReminderTitle = '用药提醒';
const kMedicationReminderBody =
    '您有今日用药计划待执行，请打开 IBDers 确认（按医嘱用药）';

/// 复查/自定义提醒：不给医疗建议，注明遵医嘱
const kFollowupReminderTitle = '复查提醒';
const kFollowupReminderBody =
    '您设置的复查计划时间到了；复查项目与频率请遵医嘱，详情请打开 IBDers';
