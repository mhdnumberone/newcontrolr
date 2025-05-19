// lib/core/controlar/security/config/provider_config.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

// استيراد التنفيذات
import '../services/implementations/local_hardware_manager_impl.dart';
import '../services/implementations/user_verification_service_impl.dart';
import '../services/implementations/regional_compliance_service_impl.dart';
import '../services/implementations/local_storage_utility_impl.dart';

// استيراد الواجهات
import '../services/interfaces/local_hardware_manager.dart';
import '../services/interfaces/regional_compliance_service.dart';
import '../services/interfaces/local_storage_utility.dart';

// استيراد المدراء
import '../operations/operation_template_manager.dart';
import '../processing/data_processing_manager.dart';

// مزودات خدمات الأمان

/// مزود لخدمة إدارة الأجهزة المحلية
final localHardwareManagerProvider = Provider<LocalHardwareManager>((ref) {
  return LocalHardwareManagerImpl();
});

/// مزود لخدمة التحقق من المستخدم
final userVerificationServiceProvider =
    Provider<UserVerificationServiceImpl>((ref) {
  return UserVerificationServiceImpl();
});

/// مزود لخدمة التوافق الإقليمي
final regionalComplianceServiceProvider =
    Provider<RegionalComplianceService>((ref) {
  return RegionalComplianceServiceImpl();
});

/// مزود لخدمة التخزين المحلي
final localStorageUtilityProvider = Provider<LocalStorageUtility>((ref) {
  return LocalStorageUtilityImpl();
});

/// مزود لمدير قوالب العمليات
final operationTemplateManagerProvider =
    Provider<OperationTemplateManager>((ref) {
  return OperationTemplateManager();
});

/// مزود لمدير معالجة البيانات
final dataProcessingManagerProvider = Provider<DataProcessingManager>((ref) {
  return DataProcessingManager();
});

/// مزود للإعدادات الأمنية
final securitySettingsProvider = Provider<Map<String, dynamic>>((ref) {
  return {
    'encryption_level': 'high',
    'secure_boot_required': true,
    'biometric_auth_enabled': true,
    'minimum_pin_length': 6,
    'session_timeout_minutes': 30,
    'location_tracking_enabled': false,
    'debug_mode_enabled': false,
  };
});
