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

/// Access/Refresh 本地持久化（MVP：SharedPreferences；后续可换 secure storage）。
class TokenStore {
  static const _kAccess = 'ibd_access_token';
  static const _kRefresh = 'ibd_refresh_token';
  static const _kUserId = 'ibd_user_id';
  static const _kPhone = 'ibd_phone';

  Future<void> save(AuthTokens tokens) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAccess, tokens.accessToken);
    await sp.setString(_kRefresh, tokens.refreshToken);
    await sp.setString(_kUserId, tokens.userId);
    if (tokens.phone != null) await sp.setString(_kPhone, tokens.phone!);
  }

  Future<AuthTokens?> load() async {
    final sp = await SharedPreferences.getInstance();
    final access = sp.getString(_kAccess);
    final refresh = sp.getString(_kRefresh);
    final userId = sp.getString(_kUserId);
    if (access == null || refresh == null || userId == null) return null;
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
      phone: sp.getString(_kPhone),
    );
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kAccess);
    await sp.remove(_kRefresh);
    await sp.remove(_kUserId);
    await sp.remove(_kPhone);
  }
}
