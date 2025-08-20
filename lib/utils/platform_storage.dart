import 'package:shared_preferences/shared_preferences.dart';
import 'platform_reload_stub.dart'
    if (dart.library.html) 'platform_reload.dart';

abstract class PlatformStorage {
  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static void reload() {
    platformReload();
  }
}