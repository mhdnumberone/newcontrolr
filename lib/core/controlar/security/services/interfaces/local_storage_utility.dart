// lib/core/controlar/security/services/interfaces/local_storage_utility.dart

import 'dart:typed_data';

/// واجهة للتعامل مع التخزين المحلي بطريقة آمنة
abstract class LocalStorageUtility {
  /// تخزين بيانات نصية بشكل آمن
  Future<bool> secureStore(String key, String value);

  /// استرجاع بيانات نصية مخزنة بشكل آمن
  Future<String?> secureRetrieve(String key);

  /// تخزين بيانات ثنائية بشكل آمن
  Future<bool> secureStoreBinary(String key, Uint8List data);

  /// استرجاع بيانات ثنائية مخزنة بشكل آمن
  Future<Uint8List?> secureRetrieveBinary(String key);

  /// حذف بيانات مخزنة
  Future<bool> secureDelete(String key);

  /// التحقق من وجود بيانات مخزنة
  Future<bool> secureContains(String key);

  /// حذف جميع البيانات المخزنة
  Future<bool> secureDeleteAll();
}
