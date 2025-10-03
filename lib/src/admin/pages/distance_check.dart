import 'package:geolocator/geolocator.dart';
import 'package:students_reminder/src/admin/pages/campus_location.dart';
import 'package:students_reminder/src/admin/models/student_geofence.dart';


Future<bool> isInsideGeofence(
  double userLat,
  double userLng,
  CampusLocation expectedCampus,
) async {
  double distance = Geolocator.distanceBetween(
    userLat,
    userLng,
    expectedCampus.latitude,
    expectedCampus.longitude,
  );

  return distance <= expectedCampus.radiusMeters;
}


Future<void> checkStudentLocation(StudentProfile student) async {
  final campusId = student.getCampusForToday();
  final expectedCampus = campusLocations[campusId]!;

  // Get current position
  Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);

  final isInside = await isInsideGeofence(
    position.latitude,
    position.longitude,
    expectedCampus,
  );

  if (isInside) {
    print("✅ Student is within the ${expectedCampus.name} geofence.");
    // Proceed with check-in logic
  } else {
    print("❌ Outside expected geofence: ${expectedCampus.name}.");
    // Show warning or disable check-in
  }
}
