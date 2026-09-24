import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 诊断上报（local-first D 类）：崩溃/性能，默认**关闭**、默认**不上传**。
class DiagnosticsPrefs extends ChangeNotifier {
  static const _kEnabled = 'ibd_diagnostics_enabled';

  bool _enabled = false;
  bool get enabled => _enabled;

  /// 本地环形缓冲（仅本机，便于用户导出查看；不落病历）
  static const int _max = 50;
  final List<String> _local = [];

  List<String> get localEvents => List.unmodifiable(_local);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _enabled = sp.getBool(_kEnabled) ?? false;
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kEnabled, v);
    notifyListeners();
  }

  /// 记录一条诊断。仅当用户打开开关时才进入上报队列语义；
  /// 默认只写本机缓冲，**绝不自动上传**。
  void record(String kind, String message) {
    final line =
        '${DateTime.now().toIso8601String().substring(0, 19)} [$kind] $message';
    _local.add(line);
    if (_local.length > _max) {
      _local.removeRange(0, _local.length - _max);
    }
    if (_enabled) {
      // 已 opt-in：目前无后端诊断端点，仅标记待上报；
      // 接入 Sentry 等时在此发送，且 payload 不含病历。
      debugPrint('[diagnostics:queued] $line');
    }
  }

  void recordError(Object error, StackTrace stack) {
    record('error', '$error');
    if (_enabled) {
      debugPrint('[diagnostics:stack] $stack');
    }
  }

  void clear() {
    _local.clear();
    notifyListeners();
  }
}
