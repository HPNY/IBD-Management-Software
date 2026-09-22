/// 远程推送 kind → 通用文案（禁止携带药品/剂量/病历）。
library;

const Map<String, ({String title, String body})> _genericCopy = {
  'medication': (title: 'IBDers', body: '您有一条用药提醒'),
  'injection': (title: 'IBDers', body: '您有一条注射提醒'),
  'followup': (title: 'IBDers', body: '您有一条复查提醒'),
  'system': (title: 'IBDers', body: '您有一条系统通知'),
};

/// 仅允许落地的通用短语白名单；其余远程文案一律丢弃并降级。
const Set<String> kAllowedRemoteCopy = {
  'IBDers',
  '您有一条用药提醒',
  '您有一条注射提醒',
  '您有一条复查提醒',
  '您有一条系统通知',
};

/// 解析远程文案：kind 映射通用短语；title/body 仅白名单命中才采用。
/// 绝不透传药品名/剂量/病历。
({String title, String body}) resolveRemoteCopy({
  String? kind,
  String? title,
  String? body,
}) {
  final generic = _genericCopy[kind] ?? _genericCopy['system']!;
  final safeTitle = (title != null && kAllowedRemoteCopy.contains(title))
      ? title
      : generic.title;
  final safeBody = (body != null && kAllowedRemoteCopy.contains(body))
      ? body
      : generic.body;
  return (title: safeTitle, body: safeBody);
}

/// 导出只读映射（测试/文档对齐用）。
Map<String, ({String title, String body})> get kGenericPushCopy =>
    Map.unmodifiable(_genericCopy);
