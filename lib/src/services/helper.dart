// lib/src/services/geofence_helper.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:students_reminder/src/services/geofence_service.dart';
import 'package:students_reminder/src/admin/models/geofence_model.dart';

/// Checks if the current GPS position is inside the geofence and
/// logs an incident or blocks based on the admin override.
/// Returns true if the clock-in/out should proceed, false to block.
Future<bool> handleClockAction({
  required BuildContext context,
  required String studentId,
  required String dateId,
  required String actionType, // 'checkin' or 'checkout'
}) async {
  // fetch geofence profile for the student/day
  final profile = await GeofenceService.instance.getProfile(
    studentId: studentId,
    dateId: dateId,
  );

  // if no profile at all, no restriction
  if (profile == null) return true;

  // get current GPS position
  final pos = await Geolocator.getCurrentPosition();

  // Floating band: always allow
  if (profile.bandType == 'floating') {
    return true;
  }

  // Pick the correct target location (check-in vs check-out)
  final GeofenceLocation target = (actionType == 'checkin')
      ? profile.checkInLocation
      : profile.checkOutLocation;

  // Calculate distance from current position to designated point
  final distance = Geolocator.distanceBetween(
    pos.latitude,
    pos.longitude,
    target.lat,
    target.lng,
  );

  if (distance <= target.radius) {
    // Inside zone: just allow
    return true;
  }

  // Outside zone:
  if (profile.outsidePolicy == 'block') {
    // Show optional message if provided
    if (profile.outsideMessage != null && profile.outsideMessage!.isNotEmpty) {
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Outside Zone'),
          content: Text(profile.outsideMessage!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            )
          ],
        ),
      );
    }
    return false; // Block clock-in/out
  } else {
    // allow_flag: allow but log incident
    await GeofenceService.instance.logIncident(
      studentId: studentId,
      dateId: dateId,
      type: actionType,
      actualLat: pos.latitude,
      actualLng: pos.longitude,
      designatedLat: target.lat,
      designatedLng: target.lng,
      distance: distance,
    );

    // Optionally still show message
    if (profile.outsideMessage != null && profile.outsideMessage!.isNotEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(profile.outsideMessage!)),
      );
    }

    return true; // Allow
  }
}
