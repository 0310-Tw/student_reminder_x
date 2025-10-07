import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:students_reminder/src/admin/models/geofence_profile.dart';
import 'package:students_reminder/src/services/geofence_service.dart';

/// Handles geofence validation before allowing clock-in/out.
/// Returns true if inside zone or allowed to proceed; false to block.
Future<bool> handleClockAction({
  required BuildContext context,
  required String studentId,
  required String dayId, // consistent with your Firestore or JmTime.dateId()
  required String actionType, // 'checkin' or 'checkout'
}) async {
  try {
    // Fetch student's geofence profile
    final GeofenceProfile? profile =
        await GeofenceService.instance.getProfile(studentId, dayId);

    // If no profile found, assume allowed (no restriction)
    if (profile == null) {
      debugPrint('ℹ️ No geofence profile found for $studentId on $dayId.');
      return true;
    }

    // Get current GPS position
    final Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Floating band → Always allowed
    if (profile.bandType == BandType.floating) {
      debugPrint('✅ Floating band: always allowed.');
      return true;
    }

    // Determine target geofence (check-in or check-out)
    final double targetLat =
        (actionType == 'checkin') ? profile.inLat : profile.outLat;
    final double targetLng =
        (actionType == 'checkin') ? profile.inLng : profile.outLng;
    final double targetRadius =
        (actionType == 'checkin') ? profile.inRadius : profile.outRadius;

    // Compute distance to designated area
    final double distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      targetLat,
      targetLng,
    );

    debugPrint(
        '📍 Distance from geofence center: ${distance.toStringAsFixed(2)}m (allowed ≤ ${targetRadius.toStringAsFixed(0)}m)');

    // ✅ Inside allowed radius
    if (distance <= targetRadius) {
      debugPrint('✅ Inside geofence zone — clock-in/out allowed.');
      return true;
    }

    // ❌ Outside zone
    if (profile.outsidePolicy == OutsidePolicy.block) {
      // Show message if available
      if (profile.outsideMessage?.isNotEmpty ?? false) {
        // ignore: use_build_context_synchronously
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Outside Zone'),
            content: Text(profile.outsideMessage!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      debugPrint('🚫 Clock-in/out blocked (outside fixed zone).');
      return false;
    } else {
      // Allow & Flag incident
      await GeofenceService.instance.logIncident(
        studentId: studentId,
        dayId: dayId,
        direction: actionType,
        actualLat: pos.latitude,
        actualLng: pos.longitude,
        designatedLat: targetLat,
        designatedLng: targetLng,
        distanceMeters: distance,
        outsideMessage: profile.outsideMessage,
      );

      if (profile.outsideMessage?.isNotEmpty ?? false) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(profile.outsideMessage!)),
        );
      }

      debugPrint('⚠️ Outside zone, but allowed & flagged.');
      return true;
    }
  } catch (e, st) {
    debugPrint('❌ Error in handleClockAction: $e\n$st');
    // If geolocation fails, default to allow (to avoid false block)
    return true;
  }
}
