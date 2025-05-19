// lib/core/controlar/security/services/interfaces/regional_compliance_service.dart

/// واجهة للتحقق من الامتثال الإقليمي والتوافق مع القوانين المحلية
abstract class RegionalComplianceService {
  /// التحقق من صلاحية استخدام الموقع في المنطقة الحالية
  Future<bool> verifyLocationCompliance();

  /// التحقق من صلاحية استخدام الكاميرا في المنطقة الحالية
  Future<bool> verifyCameraCompliance();

  /// التحقق من صلاحية استخدام الميكروفون في المنطقة الحالية
  Future<bool> verifyMicrophoneCompliance();

  /// التحقق من صلاحية استخدام الشبكة في المنطقة الحالية
  Future<bool> verifyNetworkCompliance();

  /// التحقق من تمكين الشفرة القانونية المطلوبة
  Future<bool> verifyLegalEncryptionCompliance();

  /// الحصول على المنطقة الجغرافية الحالية
  Future<String> getCurrentRegion();

  /// الحصول على بيانات المنطقة الحالية الكاملة
  Future<Map<String, dynamic>> getCurrentRegionData();

  /// التحقق من توافق المنطقة مع المتطلبات المحددة
  Future<bool> validateRegionCompliance(Map<String, dynamic> complianceRules);
}
