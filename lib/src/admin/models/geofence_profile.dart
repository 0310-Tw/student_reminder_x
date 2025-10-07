/// Geofence Profile Management System
///
/// This file contains the profile management system for storing and retrieving
/// geofence configurations per user and day of week.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/admin/models/advanced_geofence.dart';


/// Geofence profile for a specific user and day of week
class GeofenceProfile {
  /// Day of week (0 = Sunday, 6 = Saturday)
  final int dayOfWeek;

  /// User ID
  final String userId;

  /// Optional band type override for this day
  final BandType? bandTypeOverride;

  /// Outside policy override for this day
  final OutsidePolicy? outsidePolicy;

  /// Custom outside message for this day
  final String? outsideMessageText;

  /// Check-in slot configuration
  final GeofenceSlotConfig? checkInSlot;

  /// Check-out slot configuration
  final GeofenceSlotConfig? checkOutSlot;

  /// Creates a geofence profile
  const GeofenceProfile({
    required this.dayOfWeek,
    required this.userId,
    this.bandTypeOverride,
    this.outsidePolicy,
    this.outsideMessageText,
    this.checkInSlot,
    this.checkOutSlot,
  });

  /// Creates from Firestore document data
  factory GeofenceProfile.fromMap(
    Map<String, dynamic> map,
    String userId,
    int dayOfWeek,
  ) {
    return GeofenceProfile(
      dayOfWeek: dayOfWeek,
      userId: userId,
      bandTypeOverride: map['bandTypeOverride'] != null
          ? BandType.values.firstWhere((e) => e.name == map['bandTypeOverride'])
          : null,
      outsidePolicy: map['outsidePolicy'] != null
          ? OutsidePolicy.values.firstWhere(
              (e) => e.name == map['outsidePolicy'],
            )
          : null,
      outsideMessageText: map['outsideMessageText'] as String?,
      checkInSlot: map['checkInSlot'] != null
          ? GeofenceSlotConfig.fromMap(
              map['checkInSlot'] as Map<String, dynamic>,
            )
          : null,
      checkOutSlot: map['checkOutSlot'] != null
          ? GeofenceSlotConfig.fromMap(
              map['checkOutSlot'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Converts to Firestore document data
  Map<String, dynamic> toMap() {
    return {
      if (bandTypeOverride != null) 'bandTypeOverride': bandTypeOverride!.name,
      if (outsidePolicy != null) 'outsidePolicy': outsidePolicy!.name,
      if (outsideMessageText != null) 'outsideMessageText': outsideMessageText,
      if (checkInSlot != null) 'checkInSlot': checkInSlot!.toMap(),
      if (checkOutSlot != null) 'checkOutSlot': checkOutSlot!.toMap(),
    };
  }

  /// Get slot configuration for specific slot type
  GeofenceSlotConfig? slot(GeofenceSlot slotType) {
    switch (slotType) {
      case GeofenceSlot.checkIn:
        return checkInSlot;
      case GeofenceSlot.checkOut:
        return checkOutSlot;
    }
  }

  /// Check if profile has any custom configurations
  bool get hasCustomConfig {
    return bandTypeOverride != null ||
        outsidePolicy != null ||
        outsideMessageText != null ||
        checkInSlot != null ||
        checkOutSlot != null;
  }

  /// Create a copy with updated values
  GeofenceProfile copyWith({
    BandType? bandTypeOverride,
    OutsidePolicy? outsidePolicy,
    String? outsideMessageText,
    GeofenceSlotConfig? checkInSlot,
    GeofenceSlotConfig? checkOutSlot,
  }) {
    return GeofenceProfile(
      dayOfWeek: dayOfWeek,
      userId: userId,
      bandTypeOverride: bandTypeOverride ?? this.bandTypeOverride,
      outsidePolicy: outsidePolicy ?? this.outsidePolicy,
      outsideMessageText: outsideMessageText ?? this.outsideMessageText,
      checkInSlot: checkInSlot ?? this.checkInSlot,
      checkOutSlot: checkOutSlot ?? this.checkOutSlot,
    );
  }

  @override
  String toString() =>
      'GeofenceProfile(userId: $userId, dow: $dayOfWeek, band: $bandTypeOverride)';
}

/// Service for managing geofence profiles
class GeofenceProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Load geofence profile for a specific user and day of week
  static Future<GeofenceProfile?> loadGeofenceProfile(
    String userId,
    int dayOfWeek,
  ) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('geofence_profiles')
          .doc(dayOfWeek.toString());

      final snapshot = await docRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      return GeofenceProfile.fromMap(snapshot.data()!, userId, dayOfWeek);
    } catch (e) {
      print(
        'Error loading geofence profile for user $userId, day $dayOfWeek: $e',
      );
      return null;
    }
  }

  /// Save geofence profile for a specific user and day of week
  static Future<void> saveGeofenceProfile(GeofenceProfile profile) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(profile.userId)
          .collection('geofence_profiles')
          .doc(profile.dayOfWeek.toString());

      await docRef.set(profile.toMap(), SetOptions(merge: true));
    } catch (e) {
      print('Error saving geofence profile: $e');
      rethrow;
    }
  }

  /// Delete geofence profile for a specific user and day of week
  static Future<void> deleteGeofenceProfile(
    String userId,
    int dayOfWeek,
  ) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('geofence_profiles')
          .doc(dayOfWeek.toString());

      await docRef.delete();
    } catch (e) {
      print('Error deleting geofence profile: $e');
      rethrow;
    }
  }

  /// Load all geofence profiles for a user
  static Future<Map<int, GeofenceProfile>> loadAllProfiles(
    String userId,
  ) async {
    try {
      final collectionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('geofence_profiles');

      final snapshot = await collectionRef.get();

      final profiles = <int, GeofenceProfile>{};

      for (final doc in snapshot.docs) {
        final dayOfWeek = int.tryParse(doc.id);
        if (dayOfWeek != null) {
          profiles[dayOfWeek] = GeofenceProfile.fromMap(
            doc.data(),
            userId,
            dayOfWeek,
          );
        }
      }

      return profiles;
    } catch (e) {
      print('Error loading all geofence profiles for user $userId: $e');
      return {};
    }
  }

  /// Update specific slot configuration
  static Future<void> updateSlotConfig({
    required String userId,
    required int dayOfWeek,
    required GeofenceSlot slot,
    required GeofenceSlotConfig config,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('geofence_profiles')
          .doc(dayOfWeek.toString());

      final fieldName = slot == GeofenceSlot.checkIn
          ? 'checkInSlot'
          : 'checkOutSlot';

      await docRef.set({fieldName: config.toMap()}, SetOptions(merge: true));
    } catch (e) {
      print('Error updating slot config: $e');
      rethrow;
    }
  }

  /// Remove specific slot configuration
  static Future<void> removeSlotConfig({
    required String userId,
    required int dayOfWeek,
    required GeofenceSlot slot,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('geofence_profiles')
          .doc(dayOfWeek.toString());

      final fieldName = slot == GeofenceSlot.checkIn
          ? 'checkInSlot'
          : 'checkOutSlot';

      await docRef.update({fieldName: FieldValue.delete()});
    } catch (e) {
      print('Error removing slot config: $e');
      rethrow;
    }
  }

  /// Batch update multiple profiles
  static Future<void> batchUpdateProfiles(
    List<GeofenceProfile> profiles,
  ) async {
    if (profiles.isEmpty) return;

    try {
      final batch = _firestore.batch();

      for (final profile in profiles) {
        final docRef = _firestore
            .collection('users')
            .doc(profile.userId)
            .collection('geofence_profiles')
            .doc(profile.dayOfWeek.toString());

        batch.set(docRef, profile.toMap(), SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      print('Error batch updating geofence profiles: $e');
      rethrow;
    }
  }
}

/// Default campus configurations for fallback geofences
class DefaultCampusConfig {
  /// Default campus configurations by day of week
  static const Map<int, String> _campusByDay = {
    0: 'up_park', // Sunday
    1: 'up_park', // Monday
    2: 'up_park', // Tuesday
    3: 'stony_hill', // Wednesday
    4: 'stony_hill', // Thursday
    5: 'up_park', // Friday
    6: 'up_park', // Saturday
  };

  /// Get default campus slug for a day of week
  static String getDefaultCampus(int dayOfWeek) {
    return _campusByDay[dayOfWeek] ?? 'up_park';
  }

  /// Check if a day uses Stony Hill campus by default
  static bool isStonyHillDay(int dayOfWeek) {
    return _campusByDay[dayOfWeek] == 'stony_hill';
  }

  /// Check if a day uses Up Park campus by default
  static bool isUpParkDay(int dayOfWeek) {
    return _campusByDay[dayOfWeek] == 'up_park';
  }

  /// Get all campus slugs used across the week
  static Set<String> getAllCampusSlugs() {
    return _campusByDay.values.toSet();
  }
}

/// Extension methods for day of week operations
extension DayOfWeekExtension on int {
  /// Get human-readable day name
  String get dayName {
    const dayNames = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];

    if (this >= 0 && this < dayNames.length) {
      return dayNames[this];
    }
    return 'Unknown';
  }

  /// Get short day name (3 letters)
  String get shortDayName {
    const shortNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    if (this >= 0 && this < shortNames.length) {
      return shortNames[this];
    }
    return 'Unk';
  }

  /// Check if this is a weekday (Monday-Friday)
  bool get isWeekday => this >= 1 && this <= 5;

  /// Check if this is a weekend day
  bool get isWeekend => this == 0 || this == 6;

  /// Get default campus for this day
  String get defaultCampus => DefaultCampusConfig.getDefaultCampus(this);
}