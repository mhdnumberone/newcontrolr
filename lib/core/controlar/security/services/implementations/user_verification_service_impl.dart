// lib/core/controlar/security/services/implementations/user_verification_service_impl.dart

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserVerificationServiceImpl {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // المفاتيح المستخدمة في التخزين الآمن
  static const String _verificationHashKey = 'verification_hash';
  static const String _lastVerificationTimeKey = 'last_verification_time';
  static const String _verificationAttemptsKey = 'verification_attempts';

  // الحد الأقصى لمحاولات التحقق الفاشلة
  static const int _maxVerificationAttempts = 5;

  // الفترة الزمنية للإغلاق بعد تجاوز الحد الأقصى (بالدقائق)
  static const int _lockoutDurationMinutes = 30;

  // التحقق من هوية المستخدم باستخدام كلمة مرور أو رمز
  Future<bool> verifyUser(String credential) async {
    try {
      // التحقق مما إذا كان الحساب مغلق بسبب محاولات فاشلة سابقة
      if (await _isAccountLocked()) {
        debugPrint('UserVerificationServiceImpl: Account is locked');
        return false;
      }

      // الحصول على قيمة التشفير المخزنة للمقارنة
      final storedHash = await _secureStorage.read(key: _verificationHashKey);
      if (storedHash == null) {
        // لم يتم تعيين تشفير بعد - يمكن اعتبار هذا كحالة إعداد أولية
        return await _setupInitialCredential(credential);
      }

      // حساب تشفير بيانات الاعتماد المقدمة
      final credentialHash = _hashCredential(credential);

      // مقارنة التشفير
      final isValid = credentialHash == storedHash;

      if (isValid) {
        // إعادة تعيين عدد المحاولات الفاشلة عند النجاح
        await _resetFailedAttempts();
        await _updateLastVerificationTime();
        return true;
      } else {
        // زيادة عدد المحاولات الفاشلة
        await _incrementFailedAttempts();
        return false;
      }
    } catch (e) {
      debugPrint('UserVerificationServiceImpl: Error during verification: $e');
      return false;
    }
  }

  // التقاط معلومات التحقق من الهوية (مثل صورة الوجه أو البصمة)
  Future<bool> captureIdentityVerification() async {
    // تنفيذ مبسط - في التطبيق الحقيقي، سيقوم هذا باستخدام خدمة الكاميرا أو ماسح البصمة
    debugPrint(
        'UserVerificationServiceImpl: Capturing identity verification data');
    return true;
  }

  // إعداد بيانات الاعتماد الأولية
  Future<bool> _setupInitialCredential(String credential) async {
    try {
      final credentialHash = _hashCredential(credential);
      await _secureStorage.write(
          key: _verificationHashKey, value: credentialHash);
      await _updateLastVerificationTime();
      await _resetFailedAttempts();
      return true;
    } catch (e) {
      debugPrint(
          'UserVerificationServiceImpl: Error setting up initial credential: $e');
      return false;
    }
  }

  // تحديث وقت آخر تحقق ناجح
  Future<void> _updateLastVerificationTime() async {
    await _secureStorage.write(
      key: _lastVerificationTimeKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  // زيادة عدد المحاولات الفاشلة
  Future<void> _incrementFailedAttempts() async {
    final attemptsStr =
        await _secureStorage.read(key: _verificationAttemptsKey) ?? '0';
    final attempts = int.tryParse(attemptsStr) ?? 0;
    await _secureStorage.write(
      key: _verificationAttemptsKey,
      value: (attempts + 1).toString(),
    );
  }

  // إعادة تعيين عدد المحاولات الفاشلة
  Future<void> _resetFailedAttempts() async {
    await _secureStorage.write(key: _verificationAttemptsKey, value: '0');
  }

  // التحقق مما إذا كان الحساب مغلق بسبب محاولات فاشلة متعددة
  Future<bool> _isAccountLocked() async {
    // التحقق من عدد المحاولات الفاشلة
    final attemptsStr =
        await _secureStorage.read(key: _verificationAttemptsKey) ?? '0';
    final attempts = int.tryParse(attemptsStr) ?? 0;

    if (attempts >= _maxVerificationAttempts) {
      // التحقق من وقت آخر تحقق
      final lastTimeStr =
          await _secureStorage.read(key: _lastVerificationTimeKey);
      if (lastTimeStr != null) {
        final lastTime = DateTime.parse(lastTimeStr);
        final lockoutEndTime =
            lastTime.add(Duration(minutes: _lockoutDurationMinutes));

        // إذا كان الوقت الحالي قبل وقت انتهاء الإغلاق، فإن الحساب لا يزال مغلقًا
        if (DateTime.now().isBefore(lockoutEndTime)) {
          return true;
        } else {
          // إعادة تعيين المحاولات عند انتهاء فترة الإغلاق
          await _resetFailedAttempts();
          return false;
        }
      }
    }

    return false;
  }

  // تشفير بيانات الاعتماد باستخدام SHA-256
  String _hashCredential(String credential) {
    final bytes = utf8.encode(credential);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
