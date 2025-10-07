import 'dart:math';

/// Band type determines if location enforcement is fixed or floating.
enum BandType { fixed, floating }

/// Policy for handling out-of-zone conditions.
enum OutsidePolicy { block, allow, allowFlag }

/// Represents a physical campus or default location.
class CampusLocation {
  final double lat;
  final double lng;
  final double defaultRadiusMeters;
  final String name;
  final String slug;

  const CampusLocation({
    required this.lat,
    required this.lng,
    required this.defaultRadiusMeters,
    required this.name,
    required this.slug,
  });
}

/// Holds default organization-wide campus settings.
class OrgDefaults {
  final Map<String, CampusLocation> campuses;

  OrgDefaults(this.campuses);

  List<String> get availableCampuses => campuses.keys.toList();
}

/// Defines one geofence area (check-in or check-out)
class GeofenceSlot {
  final double lat;
  final double lng;
  final double radiusMeters;

  GeofenceSlot({
    required this.lat,
    required this.lng,
    required this.radiusMeters,
  });

  double distanceTo(double userLat, double userLng) {
    const R = 6371000; // meters
    final dLat = _degToRad(userLat - lat);
    final dLng = _degToRad(userLng - lng);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat)) *
            cos(_degToRad(userLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * pi / 180;
}

/// Represents resolved geofence for both check-in/out.
class EffectiveGeofence {
  final GeofenceSlot checkIn;
  final GeofenceSlot checkOut;

  EffectiveGeofence({
    required this.checkIn,
    required this.checkOut,
  });
}

/// User profile used by advanced geofence resolver.
class UserProfile {
  final String uid;
  final BandType bandType;
  final bool outsideMessageEnabled;

  UserProfile({
    required this.uid,
    this.bandType = BandType.fixed,
    this.outsideMessageEnabled = false,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      bandType: (data['bandType'] == 'floating')
          ? BandType.floating
          : BandType.fixed,
      outsideMessageEnabled: data['outsideMessageEnabled'] ?? false,
    );
  }
}

/// Represents attendance validation status
enum AttStatus { onTime, late, outside, unknown }

/// Utility to interpret status based on distance and grace time.
AttStatus resolveStatus({
  required DateTime now,
  required DateTime start,
  required int graceMinutes,
  required double distanceMeters,
  required double radiusMeters,
}) {
  final lateThreshold = start.add(Duration(minutes: graceMinutes));
  if (distanceMeters > radiusMeters) return AttStatus.outside;
  if (now.isAfter(lateThreshold)) return AttStatus.late;
  return AttStatus.onTime;
}

/// Helper for formatting distance nicely
String prettyDistance(double meters) {
  if (meters < 1000) return '${meters.toStringAsFixed(0)}m';
  return '${(meters / 1000).toStringAsFixed(2)}km';
}
