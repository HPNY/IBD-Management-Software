import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 端到端加密：密钥由用户口令 + appUserId 派生，服务端不可解密。
class BackupCrypto {
  BackupCrypto._();

  static final AesGcm _gcm = AesGcm.with256bits();

  static Future<SecretKey> deriveKey(String passphrase, String appUserId) async {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    return kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: utf8.encode(appUserId),
    );
  }

  /// 返回 {cipher, nonce} 均为 base64
  static Future<Map<String, String>> encryptJson(
    Map<String, dynamic> data, {
    required String passphrase,
    required String appUserId,
  }) async {
    final key = await deriveKey(passphrase, appUserId);
    final clear = utf8.encode(jsonEncode(data));
    final secretBox = await _gcm.encrypt(clear, secretKey: key);
    return {
      'cipher': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      // MAC 一并写入 cipher 尾部或单独存；此处附在 nonce 后拼接
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  static Future<Map<String, dynamic>> decryptJson({
    required String cipherB64,
    required String nonceB64,
    required String macB64,
    required String passphrase,
    required String appUserId,
  }) async {
    final key = await deriveKey(passphrase, appUserId);
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
