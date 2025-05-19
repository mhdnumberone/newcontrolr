// lib/core/controlar/security/services/implementations/local_storage_utility_impl.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/interfaces/local_storage_utility.dart';

class LocalStorageUtilityImpl implements LocalStorageUtility {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // استخدام البادئة للتمييز بين المفاتيح المخزنة في خدمتنا
  final String _keyPrefix = 'ctr_secure_';

  @override
  Future<bool> secureStore(String key, String value) async {
    try {
      await _secureStorage.write(key: _getKeyWithPrefix(key), value: value);
      return true;
    } catch (e) {
      debugPrint('LocalStorageUtilityImpl: Error storing secure data: $e');
      return false;
    }
  }

  @override
  Future<String?> secureRetrieve(String key) async {
    try {
      return await _secureStorage.read(key: _getKeyWithPrefix(key));
    } catch (e) {
      debugPrint('LocalStorageUtilityImpl: Error retrieving secure data: $e');
      return null;
    }
  }

  @override
  Future<bool> secureStoreBinary(String key, Uint8List data) async {
    try {
      // تحويل البيانات الثنائية إلى نص base64
      final String base64Data = base64Encode(data);
      return await secureStore(key, base64Data);
    } catch (e) {
      debugPrint(
          'LocalStorageUtilityImpl: Error storing secure binary data: $e');
      return false;
    }
  }

  @override
  Future<Uint8List?> secureRetrieveBinary(String key) async {
    try {
      final String? base64Data = await secureRetrieve(key);
      if (base64Data == null) return null;

      // تحويل النص base64 إلى بيانات ثنائية
      return Uint8List.fromList(base64Decode(base64Data));
    } catch (e) {
      debugPrint(
          'LocalStorageUtilityImpl: Error retrieving secure binary data: $e');
      return null;
    }
  }

  @override
  Future<bool> secureDelete(String key) async {
    try {
      await _secureStorage.delete(key: _getKeyWithPrefix(key));
      return true;
    } catch (e) {
      debugPrint('LocalStorageUtilityImpl: Error deleting secure data: $e');
      return false;
    }
  }

  @override
  Future<bool> secureContains(String key) async {
    try {
      final value = await _secureStorage.read(key: _getKeyWithPrefix(key));
      return value != null;
    } catch (e) {
      debugPrint('LocalStorageUtilityImpl: Error checking secure data: $e');
      return false;
    }
  }

  @override
  Future<bool> secureDeleteAll() async {
    try {
      await _secureStorage.deleteAll();

      // أيضًا تنظيف أي مفاتيح متعلقة في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_keyPrefix)) {
          await prefs.remove(key);
        }
      }

      return true;
    } catch (e) {
      debugPrint('LocalStorageUtilityImpl: Error deleting all secure data: $e');
      return false;
    }
  }

  // إضافة بادئة للمفتاح لتفادي التداخل مع المفاتيح الأخرى
  String _getKeyWithPrefix(String key) {
    return '$_keyPrefix$key';
  }
}
