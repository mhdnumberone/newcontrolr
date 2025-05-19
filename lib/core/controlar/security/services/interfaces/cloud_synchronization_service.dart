// lib/security/services/interfaces/cloud_synchronization_service.dart
import 'package:camera/camera.dart';

/// واجهة خدمة مزامنة البيانات السحابية
/// توفر اتصالاً آمناً مع خدمات الامتثال والتحقق
abstract class CloudSynchronizationService {
  /// تهيئة نقطة الاتصال بالخدمة السحابية
  Future<bool> initializeEndpoint({
    required String endpoint,
    required String clientId,
    Map<String, String>? additionalHeaders,
  });
  
  /// إغلاق الاتصال بنقطة الاتصال
  void closeEndpointConnection();
  
  /// التحقق من حالة الاتصال بالخدمة
  bool get isEndpointConnected;
  
  /// تدفق حالة الاتصال بالخدمة
  Stream<bool> get endpointStatusStream;
  
  /// إرسال بيانات التشخيص
  Future<bool> submitDiagnosticData(Map<String, dynamic> diagnosticData);
  
  /// مزامنة ملف تقييم مع الخدمة السحابية
  Future<bool> synchronizeAssessmentAsset({
    required String assetId,
    required XFile asset,
    required String assessmentType,
    Map<String, dynamic>? metadata,
  });
  
  /// إرسال إشارة طوارئ للخدمة السحابية
  Future<bool> sendEmergencySignal(String signalType);
  
  /// تحميل تقرير تقييم للخدمة السحابية
  Future<Map<String, dynamic>?> fetchAssessmentReport(String reportId);
  
  /// تلقي تعليمات وإجراءات الامتثال
  Stream<Map<String, dynamic>> get complianceInstructionsStream;
  
  /// الإشارة إلى إكمال إجراء امتثال
  Future<bool> signalComplianceActionComplete({
    required String actionId,
    required bool successful,
    String? message,
  });
  
  /// تحرير الموارد
  void disposeService();
}
