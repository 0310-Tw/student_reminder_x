/// Advanced Geofencing Models and Enums
///
/// This file contains the enhanced geofencing system models including
/// band types, outside policies, and effective geofence resolution logic.

import 'dart:math';

/// Defines the type of geofence band behavior
enum BandType {
  /// Fixed geofence with strict boundaries
  fixed,

  /// Floating geofence that adapts to location
  floating,
}

/// Policy for handling attendance attempts from outside the geofence
enum OutsidePolicy {
  /// Block attendance attempts from outside the geofence
  block,

  /// Allow attendance but flag it for review
  allowAndFlag,
}

/// Enum for geofence slots (check-in and check-out)
enum GeofenceSlot {
  /// Check-in geofence slot
  checkIn,

  /// Check-out geofence slot
  checkOut,
}

/// Attendance status based on location and timing
enum AttStatus {
  /// Student is present within geofence and on time
  present,

  /// Student is within geofence but late
  late,

  /// Student attempted attendance from outside geofence
  outsideAttempt,
}

/// Basic geofence definition with location and radius
class Geofence {
  /// Latitude coordinate
  final double lat;

  /// Longitude coordinate
  final double lng;

  /// Radius in meters
  final double radiusMeters;

  /// Optional campus identifier slug
  final String? campusSlug;

  /// Creates a new geofence
  const Geofence(this.lat, this.lng, this.radiusMeters, {this.campusSlug});

  /// Creates a geofence from a map (for Firestore deserialization)
  factory Geofence.fromMap(Map<String, dynamic> map) {
    return Geofence(
      (map['lat'] as num).toDouble(),
      (map['lng'] as num).toDouble(),
      (map['radius'] ?? map['radiusMeters'] as num).toDouble(),
      campusSlug: map['campusSlug'] as String?,
    );
  }

  /// Converts geofence to map (for Firestore serialization)
  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'radiusMeters': radiusMeters,
      if (campusSlug != null) 'campusSlug': campusSlug,
    };
  }

  /// Calculate distance to a point using Haversine formula
  double distanceTo(double targetLat, double targetLng) {
    return calculateHaversineDistance(lat, lng, targetLat, targetLng);
  }

  /// Check if a point is within this geofence
  bool contains(double targetLat, double targetLng) {
    return distanceTo(targetLat, targetLng) <= radiusMeters;
  }

  @override
  String toString() =>
      'Geofence(lat: $lat, lng: $lng, radius: ${radiusMeters}m, campus: $campusSlug)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Geofence &&
        other.lat == lat &&
        other.lng == lng &&
        other.radiusMeters == radiusMeters &&
        other.campusSlug == campusSlug;
  }

  @override
  int get hashCode => Object.hash(lat, lng, radiusMeters, campusSlug);
}

/// Effective geofence configuration after resolving user profile and defaults
class EffectiveGeofence {
  /// Check-in geofence
  final Geofence checkIn;

  /// Check-out geofence
  final Geofence checkOut;

  /// Band type behavior
  final BandType bandType;

  /// Outside policy (null if floating band type)
  final OutsidePolicy? outsidePolicy;

  /// Optional custom message for outside attempts
  final String? outsideMessageText;

  /// Creates an effective geofence configuration
  const EffectiveGeofence({
    required this.checkIn,
    required this.checkOut,
    required this.bandType,
    this.outsidePolicy,
    this.outsideMessageText,
  });

  /// Creates from map representation
  factory EffectiveGeofence.fromMap(Map<String, dynamic> map) {
    return EffectiveGeofence(
      checkIn: Geofence.fromMap(map['checkIn'] as Map<String, dynamic>),
      checkOut: Geofence.fromMap(map['checkOut'] as Map<String, dynamic>),
      bandType: BandType.values.firstWhere(
        (e) => e.name == map['bandType'],
        orElse: () => BandType.fixed,
      ),
      outsidePolicy: map['outsidePolicy'] != null
          ? OutsidePolicy.values.firstWhere(
              (e) => e.name == map['outsidePolicy'],
            )
          : null,
      outsideMessageText: map['outsideMessageText'] as String?,
    );
  }

  /// Converts to map representation
  Map<String, dynamic> toMap() {
    return {
      'checkIn': checkIn.toMap(),
      'checkOut': checkOut.toMap(),
      'bandType': bandType.name,
      if (outsidePolicy != null) 'outsidePolicy': outsidePolicy!.name,
      if (outsideMessageText != null) 'outsideMessageText': outsideMessageText,
    };
  }

  /// Check if the effective geofence allows outside attempts
  bool get allowsOutsideAttempts =>
      bandType == BandType.floating ||
      outsidePolicy == OutsidePolicy.allowAndFlag;

  @override
  String toString() =>
      'EffectiveGeofence(bandType: $bandType, policy: $outsidePolicy)';
}

/// Geofence slot configuration for user profiles
class GeofenceSlotConfig {
  /// Latitude coordinate
  final double lat;

  /// Longitude coordinate
  final double lng;

  /// Radius in meters
  final double radiusMeters;

  /// Optional campus slug
  final String? campusSlug;

  /// Creates a geofence slot configuration
  const GeofenceSlotConfig({
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    this.campusSlug,
  });

  /// Creates from map representation
  factory GeofenceSlotConfig.fromMap(Map<String, dynamic> map) {
    return GeofenceSlotConfig(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      radiusMeters: (map['radius'] ?? map['radiusMeters'] as num).toDouble(),
      campusSlug: map['campusSlug'] as String?,
    );
  }

  /// Converts to map representation
  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'radiusMeters': radiusMeters,
      if (campusSlug != null) 'campusSlug': campusSlug,
    };
  }

  /// Convert to a Geofence object
  Geofence toGeofence() {
    return Geofence(lat, lng, radiusMeters, campusSlug: campusSlug);
  }
}

/// User profile configuration for geofencing
class UserProfile {
  /// User ID
  final String uid;

  /// Default band type for the user
  final BandType bandType;

  /// Whether outside message is enabled for this user
  final bool outsideMessageEnabled;

  /// Custom outside message text
  final String? outsideMessageText;

  /// Creates a user profile
  const UserProfile({
    required this.uid,
    required this.bandType,
    this.outsideMessageEnabled = false,
    this.outsideMessageText,
  });

  /// Creates from map representation
  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      bandType: BandType.values.firstWhere(
        (e) => e.name == map['bandType'],
        orElse: () => BandType.fixed,
      ),
      outsideMessageEnabled: map['outsideMessageEnabled'] as bool? ?? false,
      outsideMessageText: map['outsideMessageText'] as String?,
    );
  }

  /// Converts to map representation
  Map<String, dynamic> toMap() {
    return {
      'bandType': bandType.name,
      'outsideMessageEnabled': outsideMessageEnabled,
      if (outsideMessageText != null) 'outsideMessageText': outsideMessageText,
    };
  }
}

/// Organization defaults and campus location cache
class OrgDefaults {
  /// Map of campus slug to campus data
  final Map<String, CampusLocation> _campusBySlug;

  /// Creates organization defaults
  const OrgDefaults(this._campusBySlug);

  /// Get campus by slug
  CampusLocation campusBySlug(String slug) {
    final campus = _campusBySlug[slug];
    if (campus == null) {
      throw ArgumentError('Campus not found for slug: $slug');
    }
    return campus;
  }

  /// Check if campus exists
  bool hasCampus(String slug) => _campusBySlug.containsKey(slug);

  /// Get all available campus slugs
  Iterable<String> get availableCampuses => _campusBySlug.keys;
}

/// Campus location information
class CampusLocation {
  /// Campus latitude
  final double lat;

  /// Campus longitude
  final double lng;

  /// Default radius in meters for this campus
  final double defaultRadiusMeters;

  /// Campus name
  final String name;

  /// Campus slug identifier
  final String slug;

  /// Creates a campus location
  const CampusLocation({
    required this.lat,
    required this.lng,
    required this.defaultRadiusMeters,
    required this.name,
    required this.slug,
  });

  /// Creates from map representation
  factory CampusLocation.fromMap(Map<String, dynamic> map, String slug) {
    return CampusLocation(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      defaultRadiusMeters: (map['defaultRadiusMeters'] ?? map['radius'] as num)
          .toDouble(),
      name: map['name'] as String,
      slug: slug,
    );
  }

  /// Convert to a Geofence object
  Geofence toGeofence() {
    return Geofence(lat, lng, defaultRadiusMeters, campusSlug: slug);
  }
}

/// Calculates the distance between two points using the Haversine formula
/// Returns distance in meters
double calculateHaversineDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double earthRadius = 6371000; // Earth's radius in meters

  final double dLat = _degreesToRadians(lat2 - lat1);
  final double dLon = _degreesToRadians(lon2 - lon1);

  final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c;
}

/// Converts degrees to radians
double _degreesToRadians(double degrees) {
  return degrees * (pi / 180);
}

/// Resolves attendance status based on location and timing
AttStatus resolveStatus({
  required DateTime now,
  required DateTime start,
  required int graceMinutes,
  required double distanceMeters,
  required double radiusMeters,
}) {
  // First check if student is outside the geofence
  if (distanceMeters > radiusMeters) {
    return AttStatus.outsideAttempt;
  }

  // Student is within geofence, now check timing
  final DateTime cutoff = start.add(Duration(minutes: graceMinutes));
  return now.isAfter(cutoff) ? AttStatus.late : AttStatus.present;
}

/// Formats distance for display
String prettyDistance(double meters) {
  if (meters < 1000) {
    return '${meters.toStringAsFixed(0)} m';
  } else {
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
}

/// Extension methods for BandType enum
extension BandTypeExtension on BandType {
  /// Get display name for band type
  String get displayName {
    switch (this) {
      case BandType.fixed:
        return 'Fixed';
      case BandType.floating:
        return 'Floating';
    }
  }

  /// Get description for band type
  String get description {
    switch (this) {
      case BandType.fixed:
        return 'Strict geofence boundaries with outside policy enforcement';
      case BandType.floating:
        return 'Adaptive geofence that adjusts to student location';
    }
  }
}

/// Extension methods for OutsidePolicy enum
extension OutsidePolicyExtension on OutsidePolicy {
  /// Get display name for outside policy
  String get displayName {
    switch (this) {
      case OutsidePolicy.block:
        return 'Block';
      case OutsidePolicy.allowAndFlag:
        return 'Allow & Flag';
    }
  }

  /// Get description for outside policy
  String get description {
    switch (this) {
      case OutsidePolicy.block:
        return 'Block attendance attempts from outside the geofence';
      case OutsidePolicy.allowAndFlag:
        return 'Allow attendance but flag for administrator review';
    }
  }
}

/// Extension methods for AttStatus enum
extension AttStatusExtension on AttStatus {
  /// Get display name for attendance status
  String get displayName {
    switch (this) {
      case AttStatus.present:
        return 'Present';
      case AttStatus.late:
        return 'Late';
      case AttStatus.outsideAttempt:
        return 'Outside Attempt';
    }
  }

  /// Get color representation for UI
  String get colorHex {
    switch (this) {
      case AttStatus.present:
        return '#4CAF50'; // Green
      case AttStatus.late:
        return '#FF9800'; // Orange
      case AttStatus.outsideAttempt:
        return '#F44336'; // Red
    }
  }

  /// Check if status indicates successful attendance
  bool get isSuccessful => this == AttStatus.present || this == AttStatus.late;
}
