/// Utility class for consistent date formatting across the app
class DateFormatter {
  /// Formats a DateTime to MM-DD-YYYY format
  /// Returns '-' if date is null
  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    
    // Ensure two-digit month and day formatting
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString();
    
    return '$month-$day-$year';
  }
  
  /// Formats a DateTime to MM-DD-YYYY HH:mm format
  /// Returns '-' if date is null
  static String formatDateTime(DateTime? date) {
    if (date == null) return '-';
    
    final dateStr = formatDate(date);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    
    return '$dateStr $hour:$minute';
  }
  
  /// Formats a DateTime to a relative time string (e.g., "2 days ago")
  /// Returns the formatted date if more than 7 days ago
  static String formatRelative(DateTime? date) {
    if (date == null) return '-';
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return formatDate(date);
    }
  }
}