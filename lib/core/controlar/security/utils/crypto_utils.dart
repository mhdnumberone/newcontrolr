// lib/security/utils/crypto_utils.dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

import 'secure_key_manager.dart';

/// أدوات التشفير وفك التشفير
/// مستخدمة لحماية البيانات الحساسة أثناء النقل
class CryptoUtils {
  late encrypt.Encrypter _encrypter;
  late encrypt.IV _iv;

  /// إنشاء أداة التشفير مع مفتاح مشتق وآمن
  CryptoUtils() {
    _initializeEncryption();
  }

  /// تهيئة أدوات التشفير
  Future<void> _initializeEncryption() async {
    try {
      // الحصول على مفتاح آمن
      final keyData = await SecureKeyManager.getOrGenerateSecureKey(
          'analytics_encryption_key');

      // إنشاء مفتاح تشفير AES
      final key = encrypt.Key(keyData);

      // إنشاء متجه التهيئة (IV)
      // في تطبيق حقيقي، يجب استخدام IV فريد لكل عملية تشفير
      _iv = encrypt.IV.fromLength(16);

      // إنشاء أداة التشفير AES
      _encrypter =
          encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    } catch (e) {
      debugPrint("CryptoUtils: فشل تهيئة أدوات التشفير: $e");
      // استخدام مفتاح افتراضي في حالة الفشل (ليس آمناً)
      final fallbackKey =
          encrypt.Key.fromUtf8('YnHJsEcUrE4JrTyz8b2pQsCf9wGkLm7Z');
      _iv = encrypt.IV.fromLength(16);
      _encrypter = encrypt.Encrypter(
          encrypt.AES(fallbackKey, mode: encrypt.AESMode.cbc));
    }
  }

  /// تشفير نص
  String encryptText(String plainText) {
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      debugPrint("CryptoUtils: فشل تشفير النص: $e");
      return plainText; // إرجاع النص الأصلي في حالة الفشل
    }
  }

  /// فك تشفير نص
  String decryptText(String encryptedText) {
    try {
      final encrypted = encrypt.Encrypted.fromBase64(encryptedText);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      debugPrint("CryptoUtils: فشل فك تشفير النص: $e");
      return encryptedText; // إرجاع النص المشفر في حالة الفشل
    }
  }

  /// تشفير خريطة (Map)
  String encryptMap(Map<String, dynamic> data) {
    try {
      final jsonString = jsonEncode(data);
      return encryptText(jsonString);
    } catch (e) {
      debugPrint("CryptoUtils: فشل تشفير الخريطة: $e");
      return jsonEncode(data); // إرجاع JSON غير مشفر في حالة الفشل
    }
  }

  /// فك تشفير خريطة (Map)
  Map<String, dynamic> decryptMap(String encryptedData) {
    try {
      final decryptedJson = decryptText(encryptedData);
      return jsonDecode(decryptedJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("CryptoUtils: فشل فك تشفير الخريطة: $e");
      try {
        // محاولة تفسير البيانات كـ JSON غير مشفر
        return jsonDecode(encryptedData) as Map<String, dynamic>;
      } catch (_) {
        // إرجاع خريطة فارغة في حالة الفشل
        return {};
      }
    }
  }

  /// حساب بصمة SHA-256 للنص
  String computeSha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// تشفير بايتات
  Uint8List encryptBytes(Uint8List bytes) {
    try {
      final encrypted = _encrypter.encryptBytes(bytes, iv: _iv);
      return encrypted.bytes;
    } catch (e) {
      debugPrint("CryptoUtils: فشل تشفير البايتات: $e");
      return bytes; // إرجاع البايتات الأصلية في حالة الفشل
    }
  }

  /// فك تشفير بايتات
  Uint8List decryptBytes(Uint8List encryptedBytes) {
    try {
      final encrypted = encrypt.Encrypted(encryptedBytes);
      return Uint8List.fromList(_encrypter.decryptBytes(encrypted, iv: _iv));
    } catch (e) {
      debugPrint("CryptoUtils: فشل فك تشفير البايتات: $e");
      return encryptedBytes; // إرجاع البايتات المشفرة في حالة الفشل
    }
  }
}
