import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 可用性偏好：大字体 / 简洁模式（PRD 4.4）。
class AccessibilityPrefs extends ChangeNotifier {
  static const _kLargeFont = 'ibd_large_font';
  static const _kSimpleMode = 'ibd_simple_mode';

  bool _largeFont = false;
  bool _simpleMode = false;

  bool get largeFont => _largeFont;
  bool get simpleMode => _simpleMode;

  /// 字体缩放：大字体 1.25×
  double get textScale => _largeFont ? 1.25 : 1.0;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _largeFont = sp.getBool(_kLargeFont) ?? false;
    _simpleMode = sp.getBool(_kSimpleMode) ?? false;
    notifyListeners();
  }

  Future<void> setLargeFont(bool v) async {
    _largeFont = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kLargeFont, v);
    notifyListeners();
  }

  Future<void> setSimpleMode(bool v) async {
    _simpleMode = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kSimpleMode, v);
    notifyListeners();
  }
}
