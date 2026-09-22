import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 推送设备令牌本地持久化：Keystore/Keychain，不进 SharedPreferences。
class PushTokenStore {
  PushTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kKey = 'ibd_push_token';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _kKey);

  Future<void> write(String token) =>
      _storage.write(key: _kKey, value: token);

  Future<void> clear() => _storage.delete(key: _kKey);
}
