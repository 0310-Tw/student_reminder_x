class StudentProfile {
  final String id;
  final String name;
  final Map<String, String> geofenceSchedule;

  StudentProfile({
    required this.id,
    required this.name,
    required this.geofenceSchedule,
  });

  String getCampusForToday() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday

    const dayMap = {
      1: "monday",
      2: "tuesday",
      3: "wednesday",
      4: "thursday",
      5: "friday",
      6: "saturday",
      7: "sunday"
    };

    final todayKey = dayMap[weekday]!;
    return geofenceSchedule[todayKey] ?? "up_park_camp"; // fallback
  }
}
