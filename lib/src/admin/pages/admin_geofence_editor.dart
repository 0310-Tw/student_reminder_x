import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/admin/models/geofence_model.dart';
import 'package:students_reminder/src/admin/models/student_geofence.dart';
import '../../services/geofence_service.dart';

class AdminGeofenceEditor extends StatefulWidget {
  final String studentId;
  final String dateId;

  const AdminGeofenceEditor({
    super.key,
    required this.studentId,
    required this.dateId,
  });

  @override
  State<AdminGeofenceEditor> createState() => _AdminGeofenceEditorState();
}

class _AdminGeofenceEditorState extends State<AdminGeofenceEditor> {
  LatLng? inLocation, outLocation;
  double inRadius = 100, outRadius = 100;
  String bandType = 'fixed';
  String outsidePolicy = 'block';
  final messageController = TextEditingController();

  late Future<StudentProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile(widget.studentId);
  }

  Future<StudentProfile> _loadProfile(String id) async {
    // 🔹 Changed from 'students' to 'users' to match your Firestore
    final snap = await FirebaseFirestore.instance.collection('users').doc(id).get();
    if (!snap.exists) {
      throw Exception('Student document not found for id: $id');
    }
    final data = snap.data()!;
    return StudentProfile(
      id: id,
      name: data['name'] ?? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
      geofenceSchedule: Map<String, String>.from(data['geofenceSchedule'] ?? {}),
    );
  }

  Future<Map<String, LatLng>> _loadCampusCoords(String campusKey) async {
    final snap = await FirebaseFirestore.instance
        .collection('campus_defaults')
        .doc(campusKey)
        .get();
    if (!snap.exists) throw Exception('No defaults found for $campusKey');
    final data = snap.data()!;
    return {
      'in': LatLng(data['inLat'], data['inLng']),
      'out': LatLng(data['outLat'], data['outLng']),
    };
  }

  Future<void> _applyDefaultCampus(StudentProfile profile) async {
    final campusKey = profile.getCampusForToday();
    try {
      final campus = await _loadCampusCoords(campusKey);
      if (mounted) {
        setState(() {
          inLocation = campus['in'];
          outLocation = campus['out'];
        });
      }
    } catch (e) {
      // silently ignore if no defaults exist
    }
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
        // Pre-set defaults once
        if (inLocation == null && outLocation == null) {
          _applyDefaultCampus(profile);
        }

        return Scaffold(
          appBar: AppBar(title: Text('Geofence Editor ${widget.dateId}')),
          body: Column(
            children: [
              Text('Default campus today: ${profile.getCampusForToday()}'),
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: inLocation ?? const LatLng(18.0, -76.8),
                    zoom: 12,
                  ),
                  markers: {
                    if (inLocation != null)
                      Marker(
                        markerId: const MarkerId('in'),
                        position: inLocation!,
                        infoWindow: const InfoWindow(title: 'Check-In'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen),
                      ),
                    if (outLocation != null)
                      Marker(
                        markerId: const MarkerId('out'),
                        position: outLocation!,
                        infoWindow: const InfoWindow(title: 'Check-Out'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed),
                      ),
                  },
                  onTap: (pos) {
                    if (inLocation == null) {
                      setState(() => inLocation = pos);
                    } else if (outLocation == null) {
                      setState(() => outLocation = pos);
                    } else {
                      setState(() {
                        inLocation = pos;
                        outLocation = null;
                      });
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: bandType,
                            decoration:
                                const InputDecoration(labelText: 'Band Type'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'fixed', child: Text('Fixed')),
                              DropdownMenuItem(
                                  value: 'floating', child: Text('Floating')),
                            ],
                            onChanged: (v) => setState(() => bandType = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: outsidePolicy,
                            decoration: const InputDecoration(
                                labelText: 'Outside Policy'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'block', child: Text('Block')),
                              DropdownMenuItem(
                                  value: 'allow_flag',
                                  child: Text('Allow & Flag')),
                            ],
                            onChanged: (v) =>
                                setState(() => outsidePolicy = v!),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                          labelText: 'Outside Message'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save Profile'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (inLocation == null || outLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap map to pick both locations')),
      );
      return;
    }

    final profile = GeofenceProfile(
      inLat: inLocation!.latitude,
      inLng: inLocation!.longitude,
      inRadius: inRadius,
      outLat: outLocation!.latitude,
      outLng: outLocation!.longitude,
      outRadius: outRadius,
      bandType: bandType,
      outsidePolicy: outsidePolicy,
      outsideMessage:
          messageController.text.isNotEmpty ? messageController.text : null,
    );

    await GeofenceService.instance.setProfile(
      studentId: widget.studentId,
      dateId: widget.dateId,
      profile: profile,
    );

    if (mounted) Navigator.pop(context);
  }
}
