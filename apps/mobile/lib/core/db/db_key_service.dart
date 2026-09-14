import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 数据库密钥：随机 32 字节，存 Android Keystore / iOS Keychain。
/// 永不上传；丢失则本地库不可恢复（故需用户备份口令或导出）。
class DbKeyService {
  DbKeyService._();
  static final DbKeyService instance = DbKeyService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _kKey = 'ibd_sqlcipher_key_v1';

  Uint8List? _cached;

  /// 获取或首次生成数据库密钥。
  Future<Uint8List> getOrCreateKey() async {
    final cached = _cached;
    if (cached != null) return cached;

    final existing = await _storage.read(key: _kKey);
    if (existing != null && existing.isNotEmpty) {
      final bytes = base64Decode(existing);
      _cached = bytes;
      return bytes;
    }

    final rng = Random.secure();
    final key = Uint8List.fromList(
      List<int>.generate(32, (_) => rng.nextInt(256)),
    );
    await _storage.write(key: _kKey, value: base64Encode(key));
    _cached = key;
    return key;
  }

  /// 轮换密钥：需在打开明文/旧密钥库后调用 rekey。
  Future<void> rotateKey(Uint8List newKey) async {
    await _storage.write(key: _kKey, value: base64Encode(newKey));
    _cached = newKey;
  }

  /// 诊断：是否存在密钥（不导出明文）。
  Future<bool> hasKey() async {
    final v = await _storage.read(key: _kKey);
    return v != null && v.isNotEmpty;
  }
}
