import 'package:cloud_firestore/cloud_firestore.dart';

/// Organization configuration service for managing campus defaults
class OrgConfigService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _orgConfigCollection = 'org_config';
  static const String _defaultsDocument = 'defaults';

  /// Default campus mapping by day of week
  /// 0 = Sunday, 1 = Monday, ..., 6 = Saturday
  static const Map<int, String> _defaultCampusByDay = {
    0: 'up_park_camp', // Sunday
    1: 'up_park_camp', // Monday
    2: 'up_park_camp', // Tuesday
    3: 'stony_hill',   // Wednesday
    4: 'stony_hill',   // Thursday
    5: 'up_park_camp', // Friday
    6: 'up_park_camp', // Saturday
  };

  /// Get default campus for a specific day of week
  static String getDefaultCampusForDay(int dayOfWeek) {
    return _defaultCampusByDay[dayOfWeek] ?? 'up_park_camp';
  }

  /// Get default campus for today
  static String getDefaultCampusForToday() {
    final today = DateTime.now();
    final dayOfWeek = today.weekday % 7; // Convert to 0-6 format
    return getDefaultCampusForDay(dayOfWeek);
  }

  /// Initialize organization defaults in Firestore
  static Future<void> initializeOrgDefaults() async {
    try {
      final docRef = _firestore
          .collection(_orgConfigCollection)
          .doc(_defaultsDocument);

      final orgDefaults = {
        'campus_by_day': _defaultCampusByDay,
        'default_geofence_settings': {
          'default_radius_meters': 100.0,
          'default_band_type': 'fixed',
          'default_outside_policy': 'allow_flag',
          'grace_period_minutes': 10,
        },
        'updated_at': FieldValue.serverTimestamp(),
      };

      await docRef.set(orgDefaults, SetOptions(merge: true));
      print('Organization defaults initialized successfully');
    } catch (e) {
      print('Error initializing org defaults: $e');
      rethrow;
    }
  }

  /// Get organization defaults from Firestore
  static Future<Map<String, dynamic>?> getOrgDefaults() async {
    try {
      final doc = await _firestore
          .collection(_orgConfigCollection)
          .doc(_defaultsDocument)
          .get();

      return doc.data();
    } catch (e) {
      print('Error getting org defaults: $e');
      return null;
    }
  }

  /// Update campus mapping for a specific day
  static Future<void> updateDefaultCampusForDay(int dayOfWeek, String campusId) async {
    try {
      await _firestore
          .collection(_orgConfigCollection)
          .doc(_defaultsDocument)
          .update({
        'campus_by_day.$dayOfWeek': campusId,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating campus for day $dayOfWeek: $e');
      rethrow;
    }
  }

  /// Get all available campus locations with their default assignments
  static Map<String, Map<String, dynamic>> getCampusAssignments() {
    final assignments = <String, Map<String, dynamic>>{};
    
    for (int day = 0; day <= 6; day++) {
      final dayName = _getDayName(day);
      final campus = getDefaultCampusForDay(day);
      
      if (!assignments.containsKey(campus)) {
        assignments[campus] = {'days': <String>[], 'count': 0};
      }
      
      assignments[campus]!['days'].add(dayName);
      assignments[campus]!['count'] = (assignments[campus]!['count'] as int) + 1;
    }
    
    return assignments;
  }

  /// Convert day number to name
  static String _getDayName(int dayOfWeek) {
    const dayNames = [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday'
    ];
    return dayNames[dayOfWeek];
  }

  /// Get day name for display
  static String getDayName(int dayOfWeek) => _getDayName(dayOfWeek);

  /// Get all days assigned to a specific campus
  static List<String> getDaysForCampus(String campusId) {
    final days = <String>[];
    for (int day = 0; day <= 6; day++) {
      if (getDefaultCampusForDay(day) == campusId) {
        days.add(_getDayName(day));
      }
    }
    return days;
  }

  /// Check if defaults are properly configured
  static Future<bool> areDefaultsConfigured() async {
    try {
      final doc = await _firestore
          .collection(_orgConfigCollection)
          .doc(_defaultsDocument)
          .get();

      return doc.exists && doc.data() != null;
    } catch (e) {
      return false;
    }
  }
}