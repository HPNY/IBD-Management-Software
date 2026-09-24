import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 轻量 i18n：中/英文案切换（PRD 4.4）。
class AppLocale extends ChangeNotifier {
  static const _kLocale = 'ibd_locale';

  Locale _locale = const Locale('zh');
  Locale get locale => _locale;
  bool get isZh => _locale.languageCode == 'zh';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final code = sp.getString(_kLocale) ?? 'zh';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    _locale = Locale(code);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLocale, code);
    notifyListeners();
  }

  String t(String key) => (isZh ? _zh : _en)[key] ?? key;

  static const Map<String, String> _zh = {
    'appTitle': 'IBDers',
    'tabHome': '首页',
    'tabCheckin': '打卡',
    'tabInjection': '注射',
    'tabAnalysis': '分析',
    'tabMe': '我的',
    'today': '今日管理',
    'quick': '快捷入口',
    'settings': '设置',
    'a11y': '可用性',
    'largeFont': '大字体模式',
    'simpleMode': '简洁模式',
    'language': '语言 / Language',
    'privacy': '隐私与备份',
    'push': '系统推送',
    'lab': '检验',
    'med': '用药',
    'export': '导出',
  };

  static const Map<String, String> _en = {
    'appTitle': 'IBDers',
    'tabHome': 'Home',
    'tabCheckin': 'Check-in',
    'tabInjection': 'Shots',
    'tabAnalysis': 'Trends',
    'tabMe': 'Me',
    'today': 'Today',
    'quick': 'Shortcuts',
    'settings': 'Settings',
    'a11y': 'Accessibility',
    'largeFont': 'Large text',
    'simpleMode': 'Simple mode',
    'language': 'Language / 语言',
    'privacy': 'Privacy & backup',
    'push': 'Push',
    'lab': 'Labs',
    'med': 'Meds',
    'export': 'Export',
  };
}
