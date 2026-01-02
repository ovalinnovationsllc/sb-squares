import 'package:flutter/material.dart';

class UserColorGenerator {
  // Cache to store generated colors for users
  static final Map<String, Color> _userColorCache = {};

  /// Get a consistent unique color for a user based on their identifier
  static Color getColorForUser(String userIdentifier) {
    // Return cached color if it exists
    if (_userColorCache.containsKey(userIdentifier)) {
      return _userColorCache[userIdentifier]!;
    }

    // Generate a unique color from the hash
    final hash = userIdentifier.hashCode.abs();

    // Use hash to generate HSL values for a vibrant, unique color
    final hue = (hash % 360).toDouble(); // 0-359 degrees
    final saturation = 0.65 + ((hash >> 8) % 35) / 100; // 65-100%
    final lightness = 0.40 + ((hash >> 16) % 20) / 100; // 40-60%

    final userColor = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();

    // Cache the color for this user
    _userColorCache[userIdentifier] = userColor;

    return userColor;
  }
  
  /// Get a lighter version of the user's color for backgrounds
  static Color getLightColorForUser(String userIdentifier) {
    final baseColor = getColorForUser(userIdentifier);
    return baseColor.withOpacity(0.3);
  }
  
  /// Get a darker version of the user's color for text/borders
  static Color getDarkColorForUser(String userIdentifier) {
    final baseColor = getColorForUser(userIdentifier);
    final hslColor = HSLColor.fromColor(baseColor);
    return hslColor.withLightness((hslColor.lightness * 0.7).clamp(0.0, 1.0)).toColor();
  }
  
  /// Clear the color cache (useful when resetting the game)
  static void clearCache() {
    _userColorCache.clear();
  }
  
  /// Get color for the current user's own squares (slightly different shade)
  static Color getOwnSquareColor(String userIdentifier) {
    final baseColor = getColorForUser(userIdentifier);
    return baseColor.withOpacity(0.8);
  }
}