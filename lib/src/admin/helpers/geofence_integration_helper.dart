// /// Geofence Integration Helper
// ///
// /// This helper provides integration functions for the existing attendance system
// /// to use the new geofence profile system seamlessly.

// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import '../models/advanced_geofence_models.dart';
// import '../services/student_geofence_profile_service.dart';

// /// Enhanced geofence helper that replaces the old helper.dart functions
// class GeofenceIntegrationHelper {
//   /// Validates attendance attempt using the enhanced geofence profile system
//   /// 
//   /// This function should replace the old handleClockAction function in helper.dart
//   static Future<bool> validateAttendanceAttempt({
//     required BuildContext context,
//     required String studentId,
//     required String actionType, // 'checkin' or 'checkout'
//   }) async {
//     try {
//       // Get current position
//       final position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       // Convert action type to GeofenceSlot
//       final slot = actionType == 'checkin' 
//           ? GeofenceSlot.checkIn 
//           : GeofenceSlot.checkOut;

//       // Validate against geofence profile
//       final result = await StudentGeofenceProfileService.validateAttendanceAttempt(
//         studentId: studentId,
//         date: DateTime.now(),
//         slot: slot,
//         currentPosition: position,
//         context: context,
//       );

//       return result.allowed;
//     } catch (e) {
//       // Handle errors (permission denied, location disabled, etc.)
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Location error: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//       return false;
//     }
//   }

//   /// Gets effective geofence for display purposes
//   static Future<EffectiveGeofence> getEffectiveGeofence(
//     String studentId, 
//     DateTime date
//   ) async {
//     return StudentGeofenceProfileService.getEffectiveGeofence(studentId, date);
//   }

//   /// Gets student profile summary for admin displays
//   static Future<StudentGeofenceProfileSummary> getProfileSummary(
//     String studentId
//   ) async {
//     return StudentGeofenceProfileService.getStudentProfileSummary(studentId);
//   }

//   /// Checks if a position is within a geofence (for UI feedback)
//   static bool isWithinGeofence(
//     Position position, 
//     Geofence geofence
//   ) {
//     final distance = geofence.distanceTo(position.latitude, position.longitude);
//     return distance <= geofence.radiusMeters;
//   }

//   /// Calculates distance from position to geofence center
//   static double calculateDistance(
//     Position position, 
//     Geofence geofence
//   ) {
//     return geofence.distanceTo(position.latitude, position.longitude);
//   }

//   /// Formats distance for display
//   static String formatDistance(double meters) {
//     return prettyDistance(meters);
//   }

//   /// Gets today's effective campus for a student (for legacy compatibility)
//   static Future<String> getTodaysCampus(String studentId) async {
//     final effective = await getEffectiveGeofence(studentId, DateTime.now());
//     return effective.checkIn.campusSlug ?? 'up_park_camp';
//   }

//   /// Creates a simple geofence profile for legacy systems
//   static Future<LegacyGeofenceProfile> getLegacyProfile({
//     required String studentId,
//     required String dateId,
//   }) async {
//     final date = DateTime.tryParse(dateId) ?? DateTime.now();
//     final effective = await getEffectiveGeofence(studentId, date);

//     return LegacyGeofenceProfile(
//       inLat: effective.checkIn.lat,
//       inLng: effective.checkIn.lng,
//       inRadius: effective.checkIn.radiusMeters,
//       outLat: effective.checkOut.lat,
//       outLng: effective.checkOut.lng,
//       outRadius: effective.checkOut.radiusMeters,
//       bandType: effective.bandType.name,
//       outsidePolicy: effective.outsidePolicy?.name ?? 'block',
//       outsideMessage: effective.outsideMessageText,
//     );
//   }
// }

// /// Legacy geofence profile for backward compatibility
// class LegacyGeofenceProfile {
//   final double inLat;
//   final double inLng;
//   final double inRadius;
//   final double outLat;
//   final double outLng;
//   final double outRadius;
//   final String bandType; // "fixed" | "floating"
//   final String outsidePolicy; // "block" | "allowAndFlag"
//   final String? outsideMessage;

//   const LegacyGeofenceProfile({
//     required this.inLat,
//     required this.inLng,
//     required this.inRadius,
//     required this.outLat,
//     required this.outLng,
//     required this.outRadius,
//     required this.bandType,
//     required this.outsidePolicy,
//     this.outsideMessage,
//   });
// }