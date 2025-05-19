// lib/security/services/interfaces/user_verification_service.dart
import 'dart:io';

/// أنواع التحقق من المستخدم
enum VerificationType {
  /// التحقق من الهوية المرئية (الوجه)
  visualIdentity,

  /// التحقق من الهوية الصوتية
  voiceIdentity,

  /// التحقق من المستندات
  documentVerification,

  /// تأكيد التواجد الحيوي
  livenessConfirmation,
}

/// نتيجة عملية التحقق
class VerificationResult {
  /// مسار الأصل المرتبط بعملية التحقق
  final String? assetPath;

  /// نتيجة عملية التحقق (حقيقي/مزيف)
  final bool isAuthentic;

  /// درجة الثقة (0.0 - 1.0)
  final double confidenceScore;

  /// رسالة إضافية
  final String? message;

  /// بيانات وصفية إضافية
  final Map<String, dynamic>? metadata;

  VerificationResult({
    this.assetPath,
    required this.isAuthentic,
    required this.confidenceScore,
    this.message,
    this.metadata,
  });
}

/// واجهة خدمة التحقق من المستخدم
abstract class UserVerificationService {
  /// بدء خدمات التحقق
  Future<bool> initializeVerificationServices();

  /// إيقاف خدمات التحقق
  Future<void> stopVerificationServices();

  /// التقاط بيانات التحقق (صورة، صوت، مستند)
  Future<VerificationResult> captureVerificationData({
    required VerificationType verificationType,
    Map<String, dynamic>? options,
  });

  /// التحقق من صحة ملف خارجي
  Future<VerificationResult> verifyExternalFile(
    File file,
    VerificationType verificationType,
  );

  /// التحقق من تواجد المستخدم الحيوي
  Future<VerificationResult> performLivenessCheck();

  /// مقارنة بيانات التحقق مع بيانات مرجعية
  Future<VerificationResult> compareWithReference({
    required String referencePath,
    required String samplePath,
    required VerificationType verificationType,
  });

  /// التقاط عدة لقطات تحقق متتالية
  Future<List<VerificationResult>> captureSequentialVerifications({
    required List<VerificationType> verificationSequence,
    Map<String, dynamic>? options,
  });

  /// الحصول على إحصائيات خدمة التحقق
  Future<Map<String, dynamic>> getVerificationServiceStats();
}
