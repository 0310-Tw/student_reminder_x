import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceStatusChecker {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fixed Band Check
  Future<Map<String, dynamic>> evaluateFixedBand({
    required double currentLat,
    required double currentLng,
    required double targetLat,
    required double targetLng,
    required double radiusMeters,
    required bool outsideMessageEnabled,
    required bool blockIfOutside,
    required String studentId,
    required String classId,
    required DateTime checkTime,
  }) async {
    // Step 1: Compute Distance
    double distance = Geolocator.distanceBetween(
      currentLat, currentLng, targetLat, targetLng,
    );

    // Step 2: Determine Status
    String status;
    String? incidentMsg;

    if (distance <= radiusMeters) {
      // Inside the geofence
      final gracePeriodMinutes = 5;
      if (checkTime.minute <= gracePeriodMinutes) {
        status = "Present";
      } else {
        status = "Late";
      }
    } else {
      // Outside the radius
      status = "Outside";
      incidentMsg = outsideMessageEnabled
          ? "You are outside the class geofence zone."
          : null;

      // Log an incident
      await _createIncidentRecord(
        studentId: studentId,
        classId: classId,
        distance: distance,
        message: incidentMsg ?? "Outside area",
        block: blockIfOutside,
      );
    }

    // Step 3: Write Attendance Record
    await _writeAttendanceRecord(
      studentId: studentId,
      classId: classId,
      checkTime: checkTime,
      distance: distance,
      status: status,
    );

    return {
      "status": status,
      "distance": distance,
      "blocked": distance > radiusMeters && blockIfOutside,
      "incident": incidentMsg,
    };
  }

  /// Floating Band Check — always allowed
  Future<Map<String, dynamic>> evaluateFloatingBand({
    required double currentLat,
    required double currentLng,
    required double targetLat,
    required double targetLng,
    required String studentId,
    required String classId,
    required DateTime checkTime,
  }) async {
    double distance = Geolocator.distanceBetween(
      currentLat, currentLng, targetLat, targetLng,
    );

    await _writeAttendanceRecord(
      studentId: studentId,
      classId: classId,
      checkTime: checkTime,
      distance: distance,
      status: "Present (Floating Band)",
    );

    return {
      "status": "Present (Floating Band)",
      "distance": distance,
      "incident": null,
    };
  }

  /* ----------------- Helpers ----------------- */

  Future<void> _writeAttendanceRecord({
    required String studentId,
    required String classId,
    required DateTime checkTime,
    required double distance,
    required String status,
  }) async {
    await _db.collection("attendance_records").add({
      "studentId": studentId,
      "classId": classId,
      "timestamp": checkTime,
      "distance": distance,
      "status": status,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createIncidentRecord({
    required String studentId,
    required String classId,
    required double distance,
    required String message,
    required bool block,
  }) async {
    await _db.collection("attendance_incidents").add({
      "studentId": studentId,
      "classId": classId,
      "distance": distance,
      "message": message,
      "block": block,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }
}
