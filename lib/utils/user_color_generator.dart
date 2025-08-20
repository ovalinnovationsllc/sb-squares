import 'dart:math';
import 'package:flutter/material.dart';

class UserColorGenerator {
  // Cache to store generated colors for users
  static final Map<String, Color> _userColorCache = {};
  
  // List of predefined vibrant colors to ensure good visibility
  static final List<Color> _predefinedColors = [
    Colors.red.shade400,
    Colors.blue.shade400,
    Colors.green.shade400,
    Colors.orange.shade400,
    Colors.purple.shade400,
    Colors.teal.shade400,
    Colors.pink.shade400,
    Colors.indigo.shade400,
    Colors.amber.shade600,
    Colors.cyan.shade400,
    Colors.lime.shade600,
    Colors.deepOrange.shade400,
    Colors.lightBlue.shade400,
    Colors.deepPurple.shade400,
    Colors.lightGreen.shade400,
    Colors.brown.shade400,
    Colors.blueGrey.shade400,
    Colors.yellow.shade700,
    Colors.red.shade600,
    Colors.blue.shade600,
    Colors.green.shade600,
    Colors.orange.shade600,
    Colors.purple.shade600,
    Colors.teal.shade600,
    Colors.pink.shade600,
    Colors.indigo.shade600,
    Colors.cyan.shade600,
    Colors.deepOrange.shade600,
    Colors.lightBlue.shade600,
    Colors.deepPurple.shade600,
  ];
  
  // Track which colors have been assigned to avoid duplicates
  static final Set<int> _usedColorIndices = {};
  static int _nextColorIndex = 0;
  
  /// Get a consistent color for a user based on their identifier
  static Color getColorForUser(String userIdentifier) {
    // Return cached color if it exists
    if (_userColorCache.containsKey(userIdentifier)) {
      return _userColorCache[userIdentifier]!;
    }
    
    // Generate a new color for this user
    Color userColor;
    
    if (_nextColorIndex < _predefinedColors.length) {
      // Use predefined colors first for better visibility
      userColor = _predefinedColors[_nextColorIndex];
      _nextColorIndex++;
    } else {
      // If we've used all predefined colors, generate a random one
      userColor = _generateRandomVibrantColor(userIdentifier);
    }
    
    // Cache the color for this user
    _userColorCache[userIdentifier] = userColor;
    
    return userColor;
  }
  
  /// Generate a random but consistent color based on the user identifier
  static Color _generateRandomVibrantColor(String userIdentifier) {
    // Use the hash of the identifier as a seed for consistency
    final hash = userIdentifier.hashCode;
    final random = Random(hash);
    
    // Generate vibrant colors by ensuring high saturation and medium lightness
    final hue = random.nextDouble() * 360; // 0-360 degrees
    final saturation = 0.6 + random.nextDouble() * 0.4; // 60-100% saturation
    final lightness = 0.4 + random.nextDouble() * 0.3; // 40-70% lightness
    
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
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
    _usedColorIndices.clear();
    _nextColorIndex = 0;
  }
  
  /// Get color for the current user's own squares (slightly different shade)
  static Color getOwnSquareColor(String userIdentifier) {
    final baseColor = getColorForUser(userIdentifier);
    return baseColor.withOpacity(0.8);
  }
}