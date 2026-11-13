import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 端到端加密：密钥由用户口令 + KDF 盐派生，服务端不可解密。
///
/// H2：盐必须是**随快照保存的随机值**，不能用 appUserId。
/// 旧版用 appUserId 当盐，换机/重装后 UUID 变化 → 旧快照永远解不开。
/// 新快照写入 `salt` 字段；无 `salt` 的历史快照回退到 appUserId（兼容）。
class BackupCrypto {
  BackupCrypto._();

  static final AesGcm _gcm = AesGcm.with256bits();
  static const iterations = 100000;
  static const saltLength = 16;

  static Future<SecretKey> deriveKey(
    String passphrase,
    List<int> salt,
  ) async {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return kdf.deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  /// 返回 {cipher, nonce, mac, salt}，均为 base64。
  static Future<Map<String, String>> encryptJson(
    Map<String, dynamic> data, {
    required String passphrase,
    required String appUserId,
  }) async {
    final rnd = Random.secure();
    final salt = List<int>.generate(saltLength, (_) => rnd.nextInt(256));
    final key = await deriveKey(passphrase, salt);
    final clear = utf8.encode(jsonEncode(data));
    final secretBox = await _gcm.encrypt(clear, secretKey: key);
    return {
      'cipher': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'salt': base64Encode(salt),
    };
  }

  static Future<Map<String, dynamic>> decryptJson({
    required String cipherB64,
    required String nonceB64,
    required String macB64,
    required String passphrase,
    required String appUserId,
    String? saltB64,
  }) async {
    // 兼容：历史快照无 salt，仍按 appUserId 派生（仅能同机恢复）
    final salt = (saltB64 != null && saltB64.isNotEmpty)
        ? base64Decode(saltB64)
        : utf8.encode(appUserId);
    final key = await deriveKey(passphrase, salt);
    final box = SecretBox(
      base64Decode(cipherB64),
      nonce: base64Decode(nonceB64),
      mac: Mac(base64Decode(macB64)),
    );
    final clear = await _gcm.decrypt(box, secretKey: key);
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  }
}

Uint8List utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s));
