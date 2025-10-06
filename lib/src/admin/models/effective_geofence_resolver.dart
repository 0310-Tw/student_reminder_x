/// Effective Geofence Resolution Service
///
/// This file contains the main logic for resolving effective geofence configurations
/// based on user profiles, day of week, and organization defaults.

import 'advanced_geofence_models.dart';
import 'geofence_profile_service.dart';

/// Service for resolving effective geofence configurations
class EffectiveGeofenceResolver {
  /// Resolves the effective geofence configuration for a user on a specific day
  ///
  /// This function combines user profile settings, day-specific overrides,
  /// and organization defaults to determine the final geofence configuration.
  static Future<EffectiveGeofence> resolveEffectiveGeofence({
    required UserProfile user,
    required int dow, // 0 = Sunday, 6 = Saturday
    required OrgDefaults defaults,
  }) async {
    // Load the user's geofence profile for this day of week
    final profile = await GeofenceProfileService.loadGeofenceProfile(
      user.uid,
      dow,
    );

    // Determine the band type (profile override takes precedence)
    final BandType bandType = profile?.bandTypeOverride ?? user.bandType;

    /// Helper function to resolve a specific geofence slot
    Geofence resolveSlot(GeofenceSlot slot) {
      // Check if user has a custom slot configuration for this day
      final slotConfig = profile?.slot(slot);
      if (slotConfig != null) {
        return Geofence(
          slotConfig.lat,
          slotConfig.lng,
          slotConfig.radiusMeters,
          campusSlug: slotConfig.campusSlug,
        );
      }

      // Fallback to default campus based on day of week
      final String defaultSlug = DefaultCampusConfig.getDefaultCampus(dow);
      final CampusLocation campus = defaults.campusBySlug(defaultSlug);

      return Geofence(
        campus.lat,
        campus.lng,
        campus.defaultRadiusMeters,
        campusSlug: defaultSlug,
      );
    }

    // Resolve check-in and check-out geofences
    final Geofence checkInFence = resolveSlot(GeofenceSlot.checkIn);
    final Geofence checkOutFence = resolveSlot(GeofenceSlot.checkOut);

    // Determine outside policy (only applies to fixed band type)
    final OutsidePolicy? outsidePolicy = (bandType == BandType.fixed)
        ? (profile?.outsidePolicy ?? OutsidePolicy.block)
        : null;

    // Determine outside message text
    final String? outsideMessageText =
        profile?.outsideMessageText ??
        (user.outsideMessageEnabled ? user.outsideMessageText : null);

    return EffectiveGeofence(
      checkIn: checkInFence,
      checkOut: checkOutFence,
      bandType: bandType,
      outsidePolicy: outsidePolicy,
      outsideMessageText: outsideMessageText,
    );
  }

  /// Batch resolve effective geofences for multiple days
  static Future<Map<int, EffectiveGeofence>> resolveMultipleDays({
    required UserProfile user,
    required List<int> days,
    required OrgDefaults defaults,
  }) async {
    final Map<int, EffectiveGeofence> results = {};

    // Load all profiles for the user at once for efficiency
    final profiles = await GeofenceProfileService.loadAllProfiles(user.uid);

    for (final day in days) {
      final profile = profiles[day];
      final bandType = profile?.bandTypeOverride ?? user.bandType;

      Geofence resolveSlot(GeofenceSlot slot) {
        final slotConfig = profile?.slot(slot);
        if (slotConfig != null) {
          return Geofence(
            slotConfig.lat,
            slotConfig.lng,
            slotConfig.radiusMeters,
            campusSlug: slotConfig.campusSlug,
          );
        }

        final String defaultSlug = DefaultCampusConfig.getDefaultCampus(day);
        final CampusLocation campus = defaults.campusBySlug(defaultSlug);

        return Geofence(
          campus.lat,
          campus.lng,
          campus.defaultRadiusMeters,
          campusSlug: defaultSlug,
        );
      }

      final checkInFence = resolveSlot(GeofenceSlot.checkIn);
      final checkOutFence = resolveSlot(GeofenceSlot.checkOut);

      final outsidePolicy = (bandType == BandType.fixed)
          ? (profile?.outsidePolicy ?? OutsidePolicy.block)
          : null;

      final outsideMessageText =
          profile?.outsideMessageText ??
          (user.outsideMessageEnabled ? user.outsideMessageText : null);

      results[day] = EffectiveGeofence(
        checkIn: checkInFence,
        checkOut: checkOutFence,
        bandType: bandType,
        outsidePolicy: outsidePolicy,
        outsideMessageText: outsideMessageText,
      );
    }

    return results;
  }

  /// Resolve effective geofence for current day
  static Future<EffectiveGeofence> resolveForToday({
    required UserProfile user,
    required OrgDefaults defaults,
  }) async {
    final int today = DateTime.now().weekday % 7; // Convert to 0-6 format
    return resolveEffectiveGeofence(user: user, dow: today, defaults: defaults);
  }

  /// Resolve effective geofences for the entire week (Sunday-Saturday)
  static Future<Map<int, EffectiveGeofence>> resolveForWeek({
    required UserProfile user,
    required OrgDefaults defaults,
  }) async {
    return resolveMultipleDays(
      user: user,
      days: List.generate(7, (index) => index), // [0, 1, 2, 3, 4, 5, 6]
      defaults: defaults,
    );
  }

  /// Resolve effective geofences for weekdays only (Monday-Friday)
  static Future<Map<int, EffectiveGeofence>> resolveForWeekdays({
    required UserProfile user,
    required OrgDefaults defaults,
  }) async {
    return resolveMultipleDays(
      user: user,
      days: [1, 2, 3, 4, 5], // Monday through Friday
      defaults: defaults,
    );
  }

  /// Check if a user has any custom geofence configurations
  static Future<bool> hasCustomConfigurations(String userId) async {
    final profiles = await GeofenceProfileService.loadAllProfiles(userId);
    return profiles.values.any((profile) => profile.hasCustomConfig);
  }

  /// Get summary of geofence configurations for a user
  static Future<GeofenceConfigSummary> getConfigurationSummary({
    required UserProfile user,
    required OrgDefaults defaults,
  }) async {
    final weekConfigs = await resolveForWeek(user: user, defaults: defaults);
    final hasCustom = await hasCustomConfigurations(user.uid);

    return GeofenceConfigSummary(
      userId: user.uid,
      defaultBandType: user.bandType,
      hasCustomConfigurations: hasCustom,
      weeklyConfigs: weekConfigs,
    );
  }
}

/// Summary of geofence configurations for a user
class GeofenceConfigSummary {
  /// User ID
  final String userId;

  /// Default band type for the user
  final BandType defaultBandType;

  /// Whether user has any custom configurations
  final bool hasCustomConfigurations;

  /// Weekly geofence configurations
  final Map<int, EffectiveGeofence> weeklyConfigs;

  /// Creates a configuration summary
  const GeofenceConfigSummary({
    required this.userId,
    required this.defaultBandType,
    required this.hasCustomConfigurations,
    required this.weeklyConfigs,
  });

  /// Get configuration for a specific day
  EffectiveGeofence? configForDay(int dayOfWeek) {
    return weeklyConfigs[dayOfWeek];
  }

  /// Get all days using fixed band type
  List<int> get fixedBandDays {
    return weeklyConfigs.entries
        .where((entry) => entry.value.bandType == BandType.fixed)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get all days using floating band type
  List<int> get floatingBandDays {
    return weeklyConfigs.entries
        .where((entry) => entry.value.bandType == BandType.floating)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get all unique campuses used across the week
  Set<String> get usedCampuses {
    final campuses = <String>{};
    for (final config in weeklyConfigs.values) {
      if (config.checkIn.campusSlug != null) {
        campuses.add(config.checkIn.campusSlug!);
      }
      if (config.checkOut.campusSlug != null) {
        campuses.add(config.checkOut.campusSlug!);
      }
    }
    return campuses;
  }

  /// Check if any day has outside policy set to allow and flag
  bool get hasAllowAndFlagDays {
    return weeklyConfigs.values.any(
      (config) => config.outsidePolicy == OutsidePolicy.allowAndFlag,
    );
  }

  /// Check if any day has custom outside messages
  bool get hasCustomMessages {
    return weeklyConfigs.values.any(
      (config) => config.outsideMessageText != null,
    );
  }

  /// Get count of days with custom configurations
  int get customConfigDays {
    // This would need to be calculated by comparing with default configs
    // For now, return 0 - this could be enhanced to track actual differences
    return hasCustomConfigurations ? weeklyConfigs.length : 0;
  }
}

/// Utility functions for geofence resolution
class GeofenceResolutionUtils {
  /// Convert DateTime weekday to our 0-6 format (Sunday = 0)
  static int dateTimeWeekdayToOurFormat(int dartWeekday) {
    // Dart: Monday = 1, Sunday = 7
    // Our format: Sunday = 0, Saturday = 6
    return dartWeekday % 7;
  }

  /// Convert our 0-6 format to DateTime weekday format
  static int ourFormatToDateTimeWeekday(int ourDay) {
    // Our format: Sunday = 0, Saturday = 6
    // Dart: Monday = 1, Sunday = 7
    return ourDay == 0 ? 7 : ourDay;
  }

  /// Get current day of week in our format
  static int getCurrentDayOfWeek() {
    return dateTimeWeekdayToOurFormat(DateTime.now().weekday);
  }

  /// Check if a specific geofence configuration is using defaults
  static bool isUsingDefaults(
    EffectiveGeofence config,
    OrgDefaults defaults,
    int dayOfWeek,
  ) {
    final expectedCampus = DefaultCampusConfig.getDefaultCampus(dayOfWeek);

    // Check if both check-in and check-out are using the expected campus
    final checkInUsesDefault = config.checkIn.campusSlug == expectedCampus;
    final checkOutUsesDefault = config.checkOut.campusSlug == expectedCampus;

    return checkInUsesDefault && checkOutUsesDefault;
  }

  /// Calculate the maximum radius used across all geofences in a configuration
  static double getMaxRadius(EffectiveGeofence config) {
    return [
      config.checkIn.radiusMeters,
      config.checkOut.radiusMeters,
    ].reduce((a, b) => a > b ? a : b);
  }

  /// Calculate the minimum radius used across all geofences in a configuration
  static double getMinRadius(EffectiveGeofence config) {
    return [
      config.checkIn.radiusMeters,
      config.checkOut.radiusMeters,
    ].reduce((a, b) => a < b ? a : b);
  }

  /// Get distance between check-in and check-out geofences
  static double getGeofenceDistance(EffectiveGeofence config) {
    return config.checkIn.distanceTo(config.checkOut.lat, config.checkOut.lng);
  }

  /// Check if check-in and check-out geofences overlap
  static bool doGeofencesOverlap(EffectiveGeofence config) {
    final distance = getGeofenceDistance(config);
    final combinedRadius =
        config.checkIn.radiusMeters + config.checkOut.radiusMeters;
    return distance < combinedRadius;
  }
}
