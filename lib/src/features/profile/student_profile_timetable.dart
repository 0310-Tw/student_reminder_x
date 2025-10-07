import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:students_reminder/src/admin/models/student_geofence.dart';

/// ---- Campus model + map ----
class CampusLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  CampusLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });
}

final Map<String, CampusLocation> campusLocations = {
  "up_park_camp": CampusLocation(
    id: "up_park_camp",
    name: "Up Park Camp",
    latitude: 18.0123,
    longitude: -76.7890,
    radiusMeters: 100,
  ),
  "stony_hill": CampusLocation(
    id: "stony_hill",
    name: "Stony Hill Campus",
    latitude: 18.1234,
    longitude: -76.8765,
    radiusMeters: 100,
  ),
};

/// ---- Timetable Page ----
class StudentTimetablePage extends StatefulWidget {
  const StudentTimetablePage({super.key});

  @override
  State<StudentTimetablePage> createState() => _StudentTimetablePageState();
}

class _StudentTimetablePageState extends State<StudentTimetablePage> {
  late Future<StudentProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _profileFuture = _loadProfile(uid);
  }

  Future<StudentProfile> _loadProfile(String id) async {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(id).get();
    final data = snap.data()!;
    return StudentProfile(
      id: id,
      name: data['name'] ??
          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
      geofenceSchedule: Map<String, String>.from(data['geofenceSchedule'] ?? {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StudentProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data!;

        // Look up campus for today by ID
        final todayCampusId = profile.getCampusForToday();
        final todayCampus = campusLocations[todayCampusId] ??
            campusLocations['up_park_camp']!;

        return Scaffold(
          appBar: AppBar(title: Text('${profile.name} – Timetable')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 🔹 Highlight today’s campus
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Campus",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            todayCampus.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                'Default Campus Locations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _buildDayRow('Monday', profile.geofenceSchedule['monday']),
              _buildDayRow('Tuesday', profile.geofenceSchedule['tuesday']),
              _buildDayRow('Wednesday', profile.geofenceSchedule['wednesday']),
              _buildDayRow('Thursday', profile.geofenceSchedule['thursday']),
              _buildDayRow('Friday', profile.geofenceSchedule['friday']),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayRow(String day, String? campusId) {
    // Look up full campus info; fallback to Up Park Camp
    final campus = campusLocations[campusId ?? 'up_park_camp'] ??
        campusLocations['up_park_camp']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              day,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            campus.name,
            style: TextStyle(color: Colors.blueGrey[700]),
          ),
        ],
      ),
    );
  }
}
