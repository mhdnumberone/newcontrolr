// lib/security/utils/secure_key_manager.dart
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// مدير المفاتيح الآمنة
/// يتعامل مع تخزين واسترجاع وإنشاء المفاتيح الآمنة
class SecureKeyManager {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  /// الحصول على مفتاح آمن أو إنشاء مفتاح جديد إذا لم يكن موجوداً
  static Future<Uint8List> getOrGenerateSecureKey(String keyId) async {
    final String? existingKey = await _secureStorage.read(key: 'sk_$keyId');
    
    if (existingKey != null && existingKey.isNotEmpty) {
      // استخدام المفتاح الموجود
      return base64Decode(existingKey);
    } else {
      // إنشاء مفتاح جديد
      final newKey = _generateSecureKey();
      await _secureStorage.write(key: 'sk_$keyId', value: base64Encode(newKey));
      return newKey;
    }
  }
  
  /// إنشاء مفتاح آمن عشوائي
  static Uint8List _generateSecureKey() {
    final random = Random.secure();
    final key = Uint8List(32); // مفتاح AES-256
    
    for (var i = 0; i < key.length; i++) {
      key[i] = random.nextInt(256);
    }
    
    return key;
  }
  
  /// مسح مفتاح آمن
  static Future<void> deleteSecureKey(String keyId) async {
    await _secureStorage.delete(key: 'sk_$keyId');
  }
  
  /// اشتقاق مفتاح من كلمة مرور
  static Uint8List deriveKeyFromPassword(
    String password, 
    Uint8List salt, 
    {int iterations = 10000}
  ) {
    final passwordBytes = utf8.encode(password);
    final result = Uint8List(32);
    
    // تنفيذ PBKDF2 باستخدام HMAC-SHA256
    var hmacSha256 = Hmac(sha256, passwordBytes);
    var keyDerivator = pbkdf2.bind(hmacSha256);
    var derivedKey = keyDerivator.convert(salt, iterations: iterations, length: 32);
    
    for (var i = 0; i < 32; i++) {
      result[i] = derivedKey.bytes[i];
    }
    
    return result;
  }
  
  /// تعيين مفتاح آمن
  static Future<void> setSecureKey(String keyId, Uint8List keyData) async {
    await _secureStorage.write(key: 'sk_$keyId', value: base64Encode(keyData));
  }
  
  /// التحقق من وجود مفتاح آمن
  static Future<bool> hasSecureKey(String keyId) async {
    final value = await _secureStorage.read(key: 'sk_$keyId');
    return value != null && value.isNotEmpty;
  }
}
