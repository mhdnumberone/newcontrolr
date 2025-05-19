// lib/security/utils/benign_headers.dart

/// ترويسات HTTP ذات مظهر عادي لتمويه الاتصالات
class BenignHeaders {
  /// الحصول على ترويسات HTTP قياسية تبدو طبيعية
  static Map<String, String> getStandardHeaders() {
    return {
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'ar,en;q=0.9',
      'User-Agent': 'ConduitSecure/2.5.14 (com.sosa-qav.es.security; Android 12; SM-A505F)',
      'X-Requested-With': 'XMLHttpRequest',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'Connection': 'keep-alive',
      'X-App-Version': '2.5.14',
    };
  }
  
  /// الحصول على ترويسات مخصصة مع تواريخ انتهاء الصلاحية وكوكيز مموهة
  static Map<String, String> getHeadersWithAuthTokens(String clientId) {
    final now = DateTime.now();
    final expiryDate = now.add(const Duration(hours: 24));
    final formattedExpiry = expiryDate.toUtc().toIso8601String();
    
    return {
      ...getStandardHeaders(),
      'Authorization': 'Bearer analytics-token-${clientId.substring(0, 8)}',
      'X-Security-Context': 'standard_analytics',
      'X-Instance-Id': clientId,
      'X-Timestamp': now.millisecondsSinceEpoch.toString(),
      'X-Token-Expiry': formattedExpiry,
    };
  }
  
  /// الحصول على ترويسات تبدو مثل تطبيق تواصل اجتماعي عادي
  static Map<String, String> getSocialMediaLikeHeaders() {
    return {
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Accept-Language': 'ar-SA,ar;q=0.9,en-US;q=0.8,en;q=0.7',
      'User-Agent': 'MobileApp/5.14.8 (Android 12; SM-A505F)',
      'X-Requested-With': 'com.social.messaging',
      'Referer': 'https://m.sosa-qav.es/',
      'Origin': 'https://m.sosa-qav.es',
      'Content-Type': 'application/json; charset=UTF-8',
      'Cache-Control': 'max-age=0',
      'Connection': 'keep-alive',
      'X-App-Platform': 'android',
    };
  }
  
  /// الحصول على ترويسات تبدو مثل تطبيق تسوق عادي
  static Map<String, String> getEcommerceLikeHeaders() {
    return {
      'Accept': 'application/json',
      'Accept-Language': 'ar-SA,ar;q=0.9,en;q=0.8',
      'User-Agent': 'ConduitShop/3.8.2 (Android 12; SM-A505F)',
      'Content-Type': 'application/json',
      'X-Client-Platform': 'android',
      'X-Client-Version': '3.8.2',
      'X-Storefront-Digest': '0a1b2c3d4e5f6g7h8i9j',
      'X-Checkout-Token': '',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'Connection': 'keep-alive',
    };
  }
  
  /// الحصول على ترويسات تبدو مثل تطبيق أخبار عادي
  static Map<String, String> getNewsLikeHeaders() {
    return {
      'Accept': 'application/json',
      'Accept-Language': 'ar-SA,ar;q=0.9,en;q=0.8',
      'User-Agent': 'NewsReader/4.2.1 (Android 12; SM-A505F)',
      'Content-Type': 'application/json',
      'X-Api-Key': 'news-reader-public-api',
      'X-App-Region': 'sa',
      'X-Reading-Preferences': 'tech,business,health',
      'Cache-Control': 'max-age=300',
      'Connection': 'keep-alive',
    };
  }
}
