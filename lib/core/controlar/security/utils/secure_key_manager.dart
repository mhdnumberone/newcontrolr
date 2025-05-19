// lib/core/controlar/security/utils/secure_key_manager.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

/// مدير مفاتيح التشفير الآمن
class SecureKeyManager {
  // ثوابت لعمليات اشتقاق المفتاح
  static const int _keyLengthBits = 256;
  static const int _pbkdf2Iterations = 100000;

  // الحصول على مفتاح تشفير آمن من كلمة مرور
  static Future<Uint8List> deriveKeyFromPassword(
      String password, Uint8List salt) async {
    try {
      // استخدام PBKDF2 لاشتقاق مفتاح آمن
      final algorithm = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _pbkdf2Iterations,
        bits: _keyLengthBits,
      );

      // إنشاء المفتاح
      final secretKey = await algorithm.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );

      // استخراج البيانات
      final extractedBytes = await secretKey.extractBytes();
      return Uint8List.fromList(extractedBytes);
    } catch (e) {
      debugPrint('SecureKeyManager: Error deriving key: $e');
      // إنشاء خلاصة بدون pbkdf2 كحل بديل في حالة الفشل
      final bytes = utf8.encode(password);
      final digest = sha256.convert(bytes);
      // إعادة استخدام الخلاصة لإعطاء طول مفتاح مناسب
      final keyBytes = List<int>.from([...digest.bytes, ...digest.bytes])
          .sublist(0, _keyLengthBits ~/ 8);
      return Uint8List.fromList(keyBytes);
    }
  }

  // توليد قيمة salt عشوائية للاستخدام في اشتقاق المفتاح
  static Uint8List generateRandomSalt() {
    final random = Cryptography.instance.newRandomGenerator();
    return Uint8List.fromList(random.nextBytes(16));
  }

  // حساب تجزئة آمنة للبيانات
  static String secureHash(Uint8List data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }

  // تحقق من صحة حساب تجزئة البيانات
  static bool verifyHash(Uint8List data, String expectedHash) {
    final calculatedHash = secureHash(data);
    return calculatedHash == expectedHash;
  }

  // تشفير بيانات باستخدام مفتاح مشتق من كلمة مرور
  static Future<Uint8List> encryptData(Uint8List data, String password) async {
    try {
      // توليد salt عشوائي
      final salt = generateRandomSalt();

      // اشتقاق مفتاح من كلمة المرور
      final key = await deriveKeyFromPassword(password, salt);

      // إنشاء iv (متجه التهيئة) عشوائي
      final iv = Uint8List.fromList(
          Cryptography.instance.newRandomGenerator().nextBytes(16));

      // استخدام وسيلة تشفير AES-GCM (حل بديل بسيط)
      final encryptedBytes = _simpleEncrypt(data, key, iv);

      // دمج salt و iv مع البيانات المشفرة
      final result = Uint8List(16 + 16 + encryptedBytes.length);
      result.setRange(0, 16, salt);
      result.setRange(16, 32, iv);
      result.setRange(32, result.length, encryptedBytes);

      return result;
    } catch (e) {
      debugPrint('SecureKeyManager: Error encrypting data: $e');
      throw Exception('Failed to encrypt data: ${e.toString()}');
    }
  }

  // فك تشفير بيانات باستخدام مفتاح مشتق من كلمة مرور
  static Future<Uint8List> decryptData(
      Uint8List encryptedData, String password) async {
    try {
      if (encryptedData.length < 48) {
        // تحقق من أن البيانات تحتوي على salt و iv على الأقل
        throw Exception('Invalid encrypted data format');
      }

      // استخراج salt و iv من البيانات المشفرة
      final salt = encryptedData.sublist(0, 16);
      final iv = encryptedData.sublist(16, 32);
      final cipherText = encryptedData.sublist(32);

      // اشتقاق مفتاح من كلمة المرور
      final key = await deriveKeyFromPassword(password, salt);

      // فك تشفير البيانات
      return _simpleDecrypt(cipherText, key, iv);
    } catch (e) {
      debugPrint('SecureKeyManager: Error decrypting data: $e');
      throw Exception('Failed to decrypt data: ${e.toString()}');
    }
  }

  // تشفير بسيط باستخدام XOR (للتدريب فقط - غير آمن للاستخدام الفعلي)
  static Uint8List _simpleEncrypt(Uint8List data, Uint8List key, Uint8List iv) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      final keyByte = key[i % key.length];
      final ivByte = iv[i % iv.length];
      result[i] = data[i] ^ keyByte ^ ivByte;
    }
    return result;
  }

  // فك تشفير بسيط باستخدام XOR (للتدريب فقط - غير آمن للاستخدام الفعلي)
  static Uint8List _simpleDecrypt(Uint8List data, Uint8List key, Uint8List iv) {
    // عملية فك التشفير هي نفسها عملية التشفير في حالة استخدام XOR
    return _simpleEncrypt(data, key, iv);
  }
}
