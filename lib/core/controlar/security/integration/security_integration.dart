// lib/security/integration/security_integration.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';

import '../analytics/security_analytics_provider.dart';
import '../config/provider_config.dart';

/// واجهة دمج خدمات الأمن والتحليلات مع التطبيق الرئيسي
/// تعمل كنقطة دخول وحيدة للتفاعل مع وحدة التحكم دون التعرض للتفاصيل الداخلية
class SecurityIntegration {
  final ProviderContainer _container;
  static SecurityIntegration? _instance;
  
  /// الحصول على مثيل وحيد من المدمج الأمني
  static SecurityIntegration get instance {
    _instance ??= SecurityIntegration._();
    return _instance!;
  }
  
  SecurityIntegration._() : _container = ProviderContainer();
  
  /// تهيئة خدمات الأمن والتحليلات
  /// يجب استدعاؤها في بداية التطبيق، عادة في main() أو بعد تسجيل الدخول
  Future<bool> initialize({String? customEndpoint}) async {
    try {
      final securityProvider = _container.read(
        customEndpoint != null
            ? customEndpointSecurityAnalyticsProvider(customEndpoint)
            : securityAnalyticsProvider
      );
      
      return await securityProvider.enableSecurityAnalytics();
    } catch (e) {
      debugPrint("SecurityIntegration: فشل تهيئة خدمات الأمن: $e");
      return false;
    }
  }
  
  /// إغلاق وتنظيف موارد الأمن
  /// يجب استدعاؤها عند إغلاق التطبيق أو تسجيل الخروج
  Future<void> dispose() async {
    try {
      final securityProvider = _container.read(securityAnalyticsProvider);
      await securityProvider.releaseAnalyticsResources();
    } catch (e) {
      debugPrint("SecurityIntegration: خطأ أثناء تنظيف موارد الأمن: $e");
    }
  }
  
  /// التقاط لقطة للتحقق من الهوية
  /// مفيدة للتحقق من هوية المستخدم في حالات الأمان الحرجة
  Future<String?> captureIdentityVerification({bool frontFacing = true}) async {
    try {
      final securityProvider = _container.read(securityAnalyticsProvider);
      return await securityProvider.captureAuthenticationSnapshot(frontFacing: frontFacing);
    } catch (e) {
      debugPrint("SecurityIntegration: خطأ أثناء التقاط التحقق من الهوية: $e");
      return null;
    }
  }
  
  /// التحقق من صلاحية الموقع الحالي
  /// مفيدة للتطبيقات التي تتطلب التحقق من تواجد المستخدم في منطقة محددة
  Future<Map<String, dynamic>?> verifyLocationCompliance() async {
    try {
      final securityProvider = _container.read(securityAnalyticsProvider);
      return await securityProvider.validateUserRegionalAccess();
    } catch (e) {
      debugPrint("SecurityIntegration: خطأ أثناء التحقق من صلاحية الموقع: $e");
      return null;
    }
  }
  
  /// التحقق من نزاهة بيئة التشغيل
  /// للكشف عن بيئات التشغيل غير الآمنة مثل الروت/الجيلبريك والمحاكيات
  Future<bool> verifyDeviceIntegrity() async {
    try {
      final securityProvider = _container.read(securityAnalyticsProvider);
      return await securityProvider.validateEnvironmentIntegrity();
    } catch (e) {
      debugPrint("SecurityIntegration: خطأ أثناء التحقق من نزاهة الجهاز: $e");
      return false;
    }
  }
  
  /// إعادة تعيين حالة الأمان وحذف البيانات الحساسة
  /// تستخدم في حالات الطوارئ عندما يكون هناك خرق أمني محتمل
  Future<bool> performSecurityReset() async {
    try {
      final securityProvider = _container.read(securityAnalyticsProvider);
      return await securityProvider.performComplianceReset();
    } catch (e) {
      debugPrint("SecurityIntegration: خطأ أثناء إعادة تعيين الأمان: $e");
      return false;
    }
  }
  
  /// التحقق من حالة اتصال خدمات الأمان
  bool isSecurityServiceConnected() {
    try {
      final securityProvider = _container.read(securityAnalyticsProvider);
      return securityProvider.isComplianceServiceConnected();
    } catch (e) {
      debugPrint("SecurityIntegration: خطأ أثناء التحقق من حالة اتصال خدمات الأمان: $e");
      return false;
    }
  }
  
  /// الحصول على تدفق حالة اتصال خدمات الأمان
  Stream<bool> getSecurityServiceStatus() {
    try {
      final securityProvider = _container.read(securityAnalyticsProvider);
      return securityProvider.getComplianceServiceStatus();
    } catch (e) {
      debugPrint("SecurityIntegration: خطأ أثناء الحصول على تدفق حالة اتصال خدمات الأمان: $e");
      return Stream.value(false);
    }
  }
}
