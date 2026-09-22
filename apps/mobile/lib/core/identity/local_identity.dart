import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 应用内身份：首启生成 UUID，不依赖系统设备标识，不强制登录。
class LocalIdentity {
  static const _kUuid = 'ibd_app_user_uuid';
  static const _kSyncOptIn = 'ibd_sync_opt_in';
  static const _kPushOptIn = 'ibd_push_opt_in';

  String? _uuid;
  bool _syncOptIn = false;
  bool _pushOptIn = false;

  String get uuid {
    final u = _uuid;
    if (u == null) {
      throw StateError('LocalIdentity not loaded');
    }
    return u;
  }

  bool get syncOptIn => _syncOptIn;
  bool get pushOptIn => _pushOptIn;
  bool get isLoaded => _uuid != null;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    var u = sp.getString(_kUuid);
    if (u == null || u.isEmpty) {
      u = const Uuid().v4();
      await sp.setString(_kUuid, u);
    }
    _uuid = u;
    _syncOptIn = sp.getBool(_kSyncOptIn) ?? false;
    _pushOptIn = sp.getBool(_kPushOptIn) ?? false;
  }

  Future<void> setSyncOptIn(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kSyncOptIn, value);
    _syncOptIn = value;
  }

  Future<void> setPushOptIn(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kPushOptIn, value);
    _pushOptIn = value;
  }
}
