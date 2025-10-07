import 'package:cloud_firestore/cloud_firestore.dart';
import 'geofence_profile.dart';
import '../../admin/pages/campus_location.dart';

/// Resolves the active geofence configuration for a user based on
/// their Firestore profile, or falls back to default campuses.
///
/// Compatible with your current `geofence_profile.dart` and
/// `campus_location.dart`.
class EffectiveGeofenceResolver {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Resolves an effective geofence for a specific user and day-of-week.
  static Future<EffectiveGeofence> resolveEffectiveGeofence({
    required String userId,
    required int dow, // 0 = Sunday
  }) async {
    try {
      // Try loading Firestore record for this user's daily profile.
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('geofence_profiles')
          .doc(dow.toString())
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final inLoc = (data['checkIn'] ?? {}) as Map<String, dynamic>;
        final outLoc = (data['checkOut'] ?? {}) as Map<String, dynamic>;

        return EffectiveGeofence(
          checkIn: Geofence(
            lat: (inLoc['lat'] ?? 0).toDouble(),
            lng: (inLoc['lng'] ?? 0).toDouble(),
            radiusMeters: (inLoc['radiusMeters'] ?? 100).toDouble(),
          ),
          checkOut: Geofence(
            lat: (outLoc['lat'] ?? 0).toDouble(),
            lng: (outLoc['lng'] ?? 0).toDouble(),
            radiusMeters: (outLoc['radiusMeters'] ?? 100).toDouble(),
          ),
          bandType: _parseBandType(data['bandType']),
          outsidePolicy: _parseOutsidePolicy(data['outsidePolicy']),
          outsideMessageText: data['outsideMessageText'],
        );
      }

      // 🔁 Fallback: Default campus rules
      return GeofenceProfile.resolve(dow: dow);
    } catch (e) {
      print('⚠️ Error resolving effective geofence: $e');
      return GeofenceProfile.resolve(dow: dow);
    }
  }

  /// Builds a map for all 7 days.
  static Future<Map<int, EffectiveGeofence>> resolveForWeek(
    String userId,
  ) async {
    final map = <int, EffectiveGeofence>{};
    for (int i = 0; i < 7; i++) {
      map[i] = await resolveEffectiveGeofence(userId: userId, dow: i);
    }
    return map;
  }

  /// Checks if user has any custom geofence profiles configured.
  static Future<bool> hasCustomConfigurations(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('geofence_profiles')
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('⚠️ Error checking custom configs: $e');
      return false;
    }
  }

  /// Converts Firestore text values safely into enums.
  static BandType _parseBandType(dynamic value) {
    if (value == 'floating') return BandType.floating;
    return BandType.fixed;
  }

  static OutsidePolicy _parseOutsidePolicy(dynamic value) {
    if (value == 'allowAndFlag' || value == 'allow_flag') {
      return OutsidePolicy.allowAndFlag;
    }
    return OutsidePolicy.block;
  }
}

/// Utility for determining current day-of-week.
class GeofenceResolutionUtils {
  /// Returns 0 = Sunday … 6 = Saturday
  static int getCurrentDayOfWeek() {
    final now = DateTime.now();
    return now.weekday % 7;
  }

  static String dayName(int dow) {
    const names = [
     // 'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
     // 'Saturday',
    ];
    if (dow < 0 || dow > 6) return 'Unknown';
    return names[dow];
  }
}
