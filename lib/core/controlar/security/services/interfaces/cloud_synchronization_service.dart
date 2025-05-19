// lib/core/controlar/security/services/interfaces/cloud_synchronization_service.dart

import 'dart:typed_data';

/// واجهة للتزامن مع الخدمات السحابية
abstract class CloudSynchronizationService {
  /// التحقق من حالة الاتصال بالخدمة السحابية
  Future<bool> checkConnectionStatus();

  /// تحميل بيانات إلى الخدمة السحابية
  Future<bool> uploadData(String dataId, Map<String, dynamic> data);

  /// تحميل ملف إلى الخدمة السحابية
  Future<String?> uploadFile(
      String fileId, Uint8List fileData, String fileName);

  /// تنزيل بيانات من الخدمة السحابية
  Future<Map<String, dynamic>?> downloadData(String dataId);

  /// تنزيل ملف من الخدمة السحابية
  Future<Uint8List?> downloadFile(String fileId);

  /// التحقق من وجود تحديثات للبيانات
  Future<bool> checkForUpdates(String dataId, DateTime lastSyncTime);

  /// مزامنة البيانات المحلية مع الخدمة السحابية
  Future<bool> synchronizeData(String dataId, Map<String, dynamic> localData);
}
