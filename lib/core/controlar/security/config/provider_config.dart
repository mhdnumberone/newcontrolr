// lib/security/config/provider_config.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/implementations/local_hardware_manager_impl.dart';
import '../services/implementations/user_verification_service_impl.dart';
import '../services/implementations/regional_compliance_service_impl.dart';
import '../services/implementations/cloud_sync_service_impl.dart';
import '../services/implementations/local_storage_utility_impl.dart';

import '../services/interfaces/local_hardware_manager.dart';
import '../services/interfaces/user_verification_service.dart';
import '../services/interfaces/regional_compliance_service.dart';
import '../services/interfaces/cloud_synchronization_service.dart';
import '../services/interfaces/local_storage_utility.dart';

import '../operations/operation_template_manager.dart';
import '../processing/data_processing_manager.dart';
import '../analytics/security_analytics_provider.dart';

// مزودات الخدمات
final localHardwareManagerProvider = Provider<LocalHardwareManager>((ref) => LocalHardwareManagerImpl());

final userVerificationServiceProvider = Provider<UserVerificationService>((ref) {
  final service = UserVerificationServiceImpl();
  ref.onDispose(() {
    service.stopVerificationServices();
  });
  return service;
});

final regionalComplianceServiceProvider = Provider<RegionalComplianceService>((ref) => RegionalComplianceServiceImpl());

final cloudSynchronizationServiceProvider = Provider<CloudSynchronizationService>((ref) {
  final service = CloudSyncServiceImpl();
  ref.onDispose(() {
    service.disposeService();
  });
  return service;
});

final localStorageUtilityProvider = Provider<LocalStorageUtility>((ref) => LocalStorageUtilityImpl());

// مزودات المديرين
final operationTemplateManagerProvider = Provider<OperationTemplateManager>((ref) {
  return OperationTemplateManager(
    verificationService: ref.watch(userVerificationServiceProvider),
    complianceService: ref.watch(regionalComplianceServiceProvider),
    storageUtility: ref.watch(localStorageUtilityProvider),
    cloudSync: ref.watch(cloudSynchronizationServiceProvider),
  );
});

final dataProcessingManagerProvider = Provider<DataProcessingManager>((ref) {
  final manager = DataProcessingManager(
    operationTemplateManager: ref.watch(operationTemplateManagerProvider),
    cloudSync: ref.watch(cloudSynchronizationServiceProvider),
    hardwareManager: ref.watch(localHardwareManagerProvider),
  );
  ref.onDispose(() {
    manager.cancelActiveOperations();
  });
  return manager;
});

// المزود الرئيسي
final securityAnalyticsProvider = Provider<SecurityAnalyticsProvider>((ref) {
  // بناء حاوية للمزودات
  final container = ProviderContainer();
  final provider = SecurityAnalyticsProvider(container);
  
  ref.onDispose(() {
    provider.releaseAnalyticsResources();
    container.dispose();
  });
  
  return provider;
});

// مزود مساعد للحصول على نطاق مخصص
final customEndpointSecurityAnalyticsProvider = Provider.family<SecurityAnalyticsProvider, String>((ref, endpoint) {
  // بناء حاوية للمزودات
  final container = ProviderContainer();
  final provider = SecurityAnalyticsProvider(container, customEndpoint: endpoint);
  
  ref.onDispose(() {
    provider.releaseAnalyticsResources();
    container.dispose();
  });
  
  return provider;
});
