// lib/core/controlar/security/processing/data_processing_manager.dart

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class DataProcessingManager {
  /// معالجة البيانات قبل الإرسال
  Future<Map<String, dynamic>> processDataForTransmission(
      Map<String, dynamic> data) async {
    try {
      // إضافة توقيت معالجة البيانات
      data['processing_timestamp'] = DateTime.now().toIso8601String();

      // إضافة توقيع للبيانات
      data['data_signature'] = _generateDataSignature(data);

      debugPrint('DataProcessingManager: Data processed for transmission');
      return data;
    } catch (e) {
      debugPrint('DataProcessingManager: Error processing data: $e');
      throw Exception('Failed to process data: $e');
    }
  }

  /// التحقق من صحة البيانات المستلمة
  Future<bool> validateReceivedData(Map<String, dynamic> data) async {
    try {
      if (!data.containsKey('data_signature')) {
        debugPrint('DataProcessingManager: Missing data signature');
        return false;
      }

      final receivedSignature = data['data_signature'];

      // نسخة من البيانات بدون التوقيع للتحقق
      final dataToVerify = Map<String, dynamic>.from(data);
      dataToVerify.remove('data_signature');

      final calculatedSignature = _generateDataSignature(dataToVerify);

      return receivedSignature == calculatedSignature;
    } catch (e) {
      debugPrint('DataProcessingManager: Error validating received data: $e');
      return false;
    }
  }

  /// تشفير البيانات الحساسة
  Future<String> encryptSensitiveData(String data, String key) async {
    // تنفيذ مبسط - في التطبيق الحقيقي، سيستخدم خوارزمية تشفير قوية
    final bytes = utf8.encode(data);
    final keyBytes = utf8.encode(key);

    // استخدام HMAC بدلاً من تشفير حقيقي للتبسيط
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(bytes);

    return '${base64Encode(bytes)}.$digest';
  }

  /// فك تشفير البيانات الحساسة
  Future<String?> decryptSensitiveData(String encryptedData, String key) async {
    try {
      final parts = encryptedData.split('.');
      if (parts.length != 2) return null;

      final encodedData = parts[0];
      final digest = parts[1];

      final bytes = base64Decode(encodedData);
      final keyBytes = utf8.encode(key);

      // التحقق من HMAC
      final hmac = Hmac(sha256, keyBytes);
      final calculatedDigest = hmac.convert(bytes).toString();

      if (calculatedDigest != digest) return null;

      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('DataProcessingManager: Error decrypting sensitive data: $e');
      return null;
    }
  }

  /// توليد قيمة تجزئة للبيانات
  String _generateDataSignature(Map<String, dynamic> data) {
    final jsonStr = jsonEncode(data);
    final bytes = utf8.encode(jsonStr);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
