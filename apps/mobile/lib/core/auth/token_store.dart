import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokens {
  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    this.phone,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String? phone;
}

/// Access/Refresh 持久化：Keystore/Keychain（C 组加固）。
/// 兼容：若 secure 无值则从旧 SharedPreferences 迁入并删除明文。
class TokenStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _kAccess = 'ibd_access_token_v2';
  static const _kRefresh = 'ibd_refresh_token_v2';
  static const _kUserId = 'ibd_user_id_v2';
  static const _kPhone = 'ibd_phone_v2';

  static const _legacy = {
    'ibd_access_token': _kAccess,
    'ibd_refresh_token': _kRefresh,
    'ibd_user_id': _kUserId,
    'ibd_phone': _kPhone,
  };

  Future<void> save(AuthTokens tokens) async {
    await _storage.write(key: _kAccess, value: tokens.accessToken);
    await _storage.write(key: _kRefresh, value: tokens.refreshToken);
    await _storage.write(key: _kUserId, value: tokens.userId);
    if (tokens.phone != null) {
      await _storage.write(key: _kPhone, value: tokens.phone);
    }
    // 保存时也清除旧明文，避免再登录残留
    final sp = await SharedPreferences.getInstance();
    for (final k in _legacy.keys) {
      await sp.remove(k);
    }
  }

  Future<AuthTokens?> load() async {
    var access = await _storage.read(key: _kAccess);
    var refresh = await _storage.read(key: _kRefresh);
    var userId = await _storage.read(key: _kUserId);
    var phone = await _storage.read(key: _kPhone);

    if (access == null || refresh == null || userId == null) {
      final migrated = await _migrateLegacy();
      access ??= migrated[0];
      refresh ??= migrated[1];
      userId ??= migrated[2];
      phone ??= migrated[3];
    }
    if (access == null || refresh == null || userId == null) return null;
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
      phone: phone,
    );
  }

  Future<List<String?>> _migrateLegacy() async {
    final sp = await SharedPreferences.getInstance();
    final access = sp.getString('ibd_access_token');
    final refresh = sp.getString('ibd_refresh_token');
    final userId = sp.getString('ibd_user_id');
    final phone = sp.getString('ibd_phone');
    if (access != null && refresh != null && userId != null) {
      await _storage.write(key: _kAccess, value: access);
      await _storage.write(key: _kRefresh, value: refresh);
      await _storage.write(key: _kUserId, value: userId);
      if (phone != null) await _storage.write(key: _kPhone, value: phone);
    }
    for (final k in _legacy.keys) {
      await sp.remove(k);
    }
    return [access, refresh, userId, phone];
  }

  Future<void> clear() async {
    for (final k in _legacy.values) {
      await _storage.delete(key: k);
    }
    final sp = await SharedPreferences.getInstance();
    for (final k in _legacy.keys) {
      await sp.remove(k);
    }
  }
}
