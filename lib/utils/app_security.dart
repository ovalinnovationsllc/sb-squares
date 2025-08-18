import 'package:flutter/foundation.dart';
import '../config/security_config.dart';

class AppSecurity {
  // Check if app is running in a secure environment
  static bool get isSecureEnvironment {
    if (kDebugMode) {
      // Development mode - allow localhost
      return true;
    }
    
    // Production mode - add your production URL checks here
    return true; // For now, allow all production environments
  }
  
  // Generate a simple session token for admin actions
  static String generateAdminToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.hashCode;
    return 'admin_${timestamp}_$random';
  }
  
  // Validate admin operations
  static bool validateAdminOperation(String email, String operation) {
    // Basic logging for security monitoring
    print('ADMIN_OPERATION: $operation by $email at ${DateTime.now()}');
    
    if (!SecurityConfig.isAdminEmail(email)) {
      print('SECURITY_WARNING: Non-admin email attempted $operation: $email');
      return false;
    }
    
    return true;
  }
  
  // Rate limiting for admin operations (simple implementation)
  static final Map<String, List<DateTime>> _operationHistory = {};
  
  static bool checkRateLimit(String email, {int maxOperations = 10, Duration window = const Duration(minutes: 1)}) {
    final now = DateTime.now();
    final windowStart = now.subtract(window);
    
    // Clean old entries
    _operationHistory[email] = _operationHistory[email]
        ?.where((time) => time.isAfter(windowStart))
        .toList() ?? [];
    
    // Check if under limit
    if (_operationHistory[email]!.length >= maxOperations) {
      print('RATE_LIMIT_EXCEEDED: $email attempted too many operations');
      return false;
    }
    
    // Record this operation
    _operationHistory[email]!.add(now);
    return true;
  }
  
  // Security headers for any API calls
  static Map<String, String> getHeaders() {
    return {
      ...SecurityConfig.getSecurityHeaders(),
      'X-Timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };
  }
}