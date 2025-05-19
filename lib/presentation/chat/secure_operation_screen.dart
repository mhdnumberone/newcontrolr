// lib/presentation/chat/secure_operation_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/controlar/security/integration/security_integration.dart';
import '../../core/logging/logger_provider.dart';

class SecureOperationScreen extends ConsumerStatefulWidget {
  final String title;
  final String description;
  final Widget Function(BuildContext) operationBuilder;

  const SecureOperationScreen({
    super.key,
    required this.title,
    required this.description,
    required this.operationBuilder,
  });

  @override
  ConsumerState<SecureOperationScreen> createState() =>
      _SecureOperationScreenState();
}

class _SecureOperationScreenState extends ConsumerState<SecureOperationScreen> {
  bool _isVerifying = false;
  bool _isLocationVerified = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.cairo()),
        actions: [
          // مؤشر حالة التحقق من الموقع
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              _isLocationVerified ? Icons.location_on : Icons.location_off,
              color:
                  _isLocationVerified ? Colors.green[300] : Colors.orange[300],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط حالة التحقق من الموقع
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _errorMessage != null ? 45.0 : 0.0,
            color: Colors.red.shade700,
            width: double.infinity,
            child: _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                            });
                          },
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // شرح العملية الآمنة
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'عملية آمنة',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.description,
                      style: GoogleFonts.cairo(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: _isVerifying
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isVerifying
                            ? 'جاري التحقق...'
                            : _isLocationVerified
                                ? 'تم التحقق من الموقع'
                                : 'التحقق من الموقع',
                        style: GoogleFonts.cairo(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLocationVerified
                            ? Colors.green
                            : theme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isVerifying ? null : _verifyLocation,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // محتوى العملية الآمنة (يظهر فقط بعد التحقق من الموقع)
          Expanded(
            child: _isLocationVerified
                ? widget.operationBuilder(context)
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_disabled,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'يرجى التحقق من الموقع أولاً',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'لإتمام العملية، يجب التحقق من وجودك في موقع آمن',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyLocation() async {
    final logger = ref.read(appLoggerProvider);

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final locationStatus =
          await SecurityIntegration.instance.verifyLocationCompliance();

      if (locationStatus != null &&
          locationStatus['compliance_status'] == true) {
        logger.info(
            "SecureOperationScreen", "Location verification successful");

        setState(() {
          _isLocationVerified = true;
          _isVerifying = false;
        });
      } else {
        logger.warn("SecureOperationScreen",
            "Location verification failed: ${locationStatus?['reason'] ?? 'unknown reason'}");

        setState(() {
          _isLocationVerified = false;
          _isVerifying = false;
          _errorMessage =
              'فشل التحقق من الموقع. تأكد من وجودك في موقع مصرح به للعمليات الآمنة.';
        });
      }
    } catch (e) {
      logger.error(
          "SecureOperationScreen", "Error during location verification", e);

      setState(() {
        _isLocationVerified = false;
        _isVerifying = false;
        _errorMessage =
            'حدث خطأ أثناء التحقق من الموقع. يرجى المحاولة مرة أخرى.';
      });
    }
  }
}
