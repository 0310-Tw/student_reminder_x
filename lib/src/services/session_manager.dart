import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _key = 'loginState';
  static const maxAge = Duration(minutes: 35);

  //Mark that the user has  logged in
  static Future<void> onLoginSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  //Has Login State Expired
  static Future<bool> isExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_key);
      if (ts == null) return true; // Consider expired if no login timestamp

      final loginTime = DateTime.fromMillisecondsSinceEpoch(ts);
      return DateTime.now().difference(loginTime) > maxAge;
    } catch (e) {
      print('Error checking session expiry: $e');
      return true; // Consider expired on error for security
    }
  }
}
