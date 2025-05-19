// lib/security/utils/jitter_delay.dart
import 'dart:async';
import 'dart:math';

/// أداة تأخير متغير
/// تستخدم لإضافة تأخير عشوائي لعمليات الاتصال
/// لتمويه أنماط حركة المرور والتخفيف من هجمات توقيت العمليات
class JitterDelay {
  /// إنشاء تأخير عشوائي ضمن النطاق المحدد
  static Future<void> randomDelay({
    required int minMs,
    required int maxMs,
  }) async {
    if (minMs < 0) minMs = 0;
    if (maxMs < minMs) maxMs = minMs;
    
    final random = Random.secure();
    final delayMs = minMs + random.nextInt(maxMs - minMs + 1);
    
    await Future.delayed(Duration(milliseconds: delayMs));
  }
  
  /// إنشاء تأخير عشوائي تبعاً لتوزيع مثلثي
  /// حيث يكون التأخير أكثر احتمالاً حول القيمة المتوسطة
  static Future<void> triangularDelay({
    required int minMs,
    required int targetMs,
    required int maxMs,
  }) async {
    if (minMs < 0) minMs = 0;
    if (maxMs < minMs) maxMs = minMs;
    if (targetMs < minMs) targetMs = minMs;
    if (targetMs > maxMs) targetMs = maxMs;
    
    final random = Random.secure();
    final f = random.nextDouble();
    int delayMs;
    
    if (f <= (targetMs - minMs) / (maxMs - minMs)) {
      delayMs = minMs + sqrt(f * (maxMs - minMs) * (targetMs - minMs)).round();
    } else {
      delayMs = maxMs - sqrt((1 - f) * (maxMs - minMs) * (maxMs - targetMs)).round();
    }
    
    await Future.delayed(Duration(milliseconds: delayMs));
  }
  
  /// إنشاء تأخير متغير يتناسب مع أنماط حركة المرور الحقيقية
  static Future<void> authenticLookingDelay({
    required bool isHighPriority,
  }) async {
    final random = Random.secure();
    
    if (isHighPriority) {
      // تأخير قصير للعمليات عالية الأولوية (50-150 مللي ثانية)
      await randomDelay(minMs: 50, maxMs: 150);
    } else {
      // تأخير طبيعي بتوزيع مثلثي للعمليات العادية
      // يشبه زمن الاستجابة الطبيعي للتطبيقات الشرعية
      await triangularDelay(minMs: 100, targetMs: 300, maxMs: 800);
    }
  }
}
