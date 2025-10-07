// lib/src/services/geofence_helper.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:students_reminder/src/admin/models/geofence_model.dart';
import 'package:students_reminder/src/features/geofence/geofence_service.dart';

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
  final GeofenceProfile profile = await GeofenceService.instance.getProfile(
    studentId: studentId,
    dateId: dateId,
  );

  // get current GPS position
  final pos = await Geolocator.getCurrentPosition();

  // Floating band: always allow
  if (profile.bandType == 'floating') {
    return true;
  }

  // Pick the correct target location (check-in vs check-out)
  final double targetLat;
  final double targetLng;
  final double targetRadius;

  if (actionType == 'checkin') {
    targetLat = profile.inLat;
    targetLng = profile.inLng;
    targetRadius = profile.inRadius;
  } else {
    targetLat = profile.outLat;
    targetLng = profile.outLng;
    targetRadius = profile.outRadius;
  }

  // Calculate distance from current position to designated point
  final distance = Geolocator.distanceBetween(
    pos.latitude,
    pos.longitude,
    targetLat,
    targetLng,
  );

  if (distance <= targetRadius) {
    // Inside zone: just allow
    return true;
  }

  // Outside zone:
  print(
    '🌐 Outside geofence - Distance: ${distance.toInt()}m, Policy: ${profile.outsidePolicy}',
  );
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
            ),
          ],
        ),
      );
    }
    return false; // Block clock-in/out
  } else if (profile.outsidePolicy == 'allow_flag') {
    // allow_flag: allow but log incident
    print(
      '🚨 Creating geofence incident: ${actionType.toUpperCase()} violation - Distance: ${distance.toInt()}m',
    );
    await GeofenceService.instance.logIncident(
      studentId: studentId,
      dateId: dateId,
      type: actionType,
      actualLat: pos.latitude,
      actualLng: pos.longitude,
      designatedLat: targetLat,
      designatedLng: targetLng,
      distance: distance,
    );
    print('✅ Geofence incident created successfully');

    // Optionally still show message
    if (profile.outsideMessage != null && profile.outsideMessage!.isNotEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(profile.outsideMessage!)));
    }

    return true; // Allow
  } else {
    // Default case for 'allow' policy (no incident logging)
    print('✅ Allow policy - no incident logged');
    return true; // Allow
  }
}