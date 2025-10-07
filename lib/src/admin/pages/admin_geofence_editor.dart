import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/admin/models/geofence_profile.dart';
import 'package:students_reminder/src/admin/models/student_geofence.dart';
import 'package:students_reminder/src/services/geofence_service.dart';

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
  BandType bandType = BandType.fixed;
  OutsidePolicy outsidePolicy = OutsidePolicy.block;
  final messageController = TextEditingController();

  late Future<StudentProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile(widget.studentId);
  }

  Future<StudentProfile> _loadProfile(String id) async {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(id).get();

    if (!snap.exists) {
      throw Exception('Student not found for ID: $id');
    }

    final data = snap.data()!;
    return StudentProfile(
      id: id,
      name: data['name'] ??
          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
      geofenceSchedule: Map<String, String>.from(
        data['geofenceSchedule'] ?? {},
      ),
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
      debugPrint('⚠️ Failed to apply campus defaults: $e');
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
        if (inLocation == null && outLocation == null) {
          _applyDefaultCampus(profile);
        }

        return Scaffold(
          appBar: AppBar(title: Text('Geofence Editor — ${widget.dateId}')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Default campus today: ${profile.getCampusForToday()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: inLocation ?? const LatLng(18.01649, -76.78510),
                    zoom: 14,
                  ),
                  markers: {
                    if (inLocation != null)
                      Marker(
                        markerId: const MarkerId('checkin'),
                        position: inLocation!,
                        infoWindow: const InfoWindow(title: 'Check-In'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen,
                        ),
                      ),
                    if (outLocation != null)
                      Marker(
                        markerId: const MarkerId('checkout'),
                        position: outLocation!,
                        infoWindow: const InfoWindow(title: 'Check-Out'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                      ),
                  },
                  onTap: (pos) {
                    setState(() {
                      if (inLocation == null) {
                        inLocation = pos;
                      } else if (outLocation == null) {
                        outLocation = pos;
                      } else {
                        inLocation = pos;
                        outLocation = null;
                      }
                    });
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
                          child: DropdownButtonFormField<BandType>(
                            value: bandType,
                            decoration:
                                const InputDecoration(labelText: 'Band Type'),
                            items: const [
                              DropdownMenuItem(
                                  value: BandType.fixed, child: Text('Fixed')),
                              DropdownMenuItem(
                                  value: BandType.floating,
                                  child: Text('Floating')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => bandType = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<OutsidePolicy>(
                            value: outsidePolicy,
                            decoration: const InputDecoration(
                                labelText: 'Outside Policy'),
                            items: const [
                              DropdownMenuItem(
                                  value: OutsidePolicy.block,
                                  child: Text('Block')),
                              DropdownMenuItem(
                                  value: OutsidePolicy.allowAndFlag,
                                  child: Text('Allow & Flag')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => outsidePolicy = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'Outside Message (optional)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      onPressed: _saveProfile,
                      label: const Text('Save Geofence Profile'),
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
        const SnackBar(
          content: Text('Please tap the map to set both Check-In and Check-Out.'),
        ),
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geofence profile saved successfully!')),
      );
      Navigator.pop(context);
    }
  }
}
