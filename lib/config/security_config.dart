class SecurityConfig {
  // Admin email domains - only emails from these domains can be admins
  static const List<String> adminDomains = [
    'ovalinnovationsllc.com',
  ];
  
  // Specific admin emails - these emails are guaranteed admin access
  static const List<String> adminEmails = [
    'bills@ovalinnovationsllc.com',
  ];
  
  // App settings
  static const bool requireAdminForAccess = true;
  static const int maxEntriesPerUser = 100;
  static const bool enableUserSelfRegistration = false;
  
  // Check if an email should have admin privileges
  static bool isAdminEmail(String email) {
    final lowercaseEmail = email.toLowerCase().trim();
    
    // Check against specific admin emails
    if (adminEmails.contains(lowercaseEmail)) {
      return true;
    }
    
    // Check against admin domains
    for (final domain in adminDomains) {
      if (lowercaseEmail.endsWith('@$domain')) {
        return true;
      }
    }
    
    return false;
  }
  
  // Check if user has admin access to the application
  static bool hasAdminAccess(String email, bool isAdminInDb) {
    if (!requireAdminForAccess) return true;
    
    // Must be admin in database AND from approved email/domain
    return isAdminInDb && isAdminEmail(email);
  }
  
  // Get app version info
  static const String appVersion = '1.0.0';
  static const String appName = 'Super Bowl Squares Admin';
  
  // Security headers for API calls (if needed later)
  static Map<String, String> getSecurityHeaders() {
    return {
      'X-App-Version': appVersion,
      'X-App-Name': appName,
      'Content-Type': 'application/json',
    };
  }
}