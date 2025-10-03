import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _key = 'loginState';
  static const maxAge = Duration(minutes: 35);

  //Mark that the user has  logged in
  static Future<void> onLoginSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_key, timestamp);
    print(
      '*** SessionManager: Login success recorded at $timestamp (${DateTime.now()})',
    );
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

      print('*** SessionManager: Login timestamp: $ts');

      if (ts == null) {
        print('*** SessionManager: No login timestamp found, session expired');
        return true; // Consider expired if no login timestamp
      }

      final loginTime = DateTime.fromMillisecondsSinceEpoch(ts);
      final now = DateTime.now();
      final difference = now.difference(loginTime);
      final isExpired = difference > maxAge;

      print('*** SessionManager: Login time: $loginTime');
      print('*** SessionManager: Current time: $now');
      print('*** SessionManager: Difference: ${difference.inMinutes} minutes');
      print('*** SessionManager: Max age: ${maxAge.inMinutes} minutes');
      print('*** SessionManager: Is expired: $isExpired');

      return isExpired;
    } catch (e) {
      print('Error checking session expiry: $e');
      return true; // Consider expired on error for security
    }
  }
}
