import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:students_reminder/src/admin/models/geofence_model.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Geofence Editor ${widget.dateId}')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(18.0, -76.8),
                zoom: 12,
              ),
              markers: {
                if (inLocation != null)
                  Marker(
                    markerId: const MarkerId('in'),
                    position: inLocation!,
                    infoWindow: const InfoWindow(title: 'Check-In'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  ),
                if (outLocation != null)
                  Marker(
                    markerId: const MarkerId('out'),
                    position: outLocation!,
                    infoWindow: const InfoWindow(title: 'Check-Out'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
                        decoration: const InputDecoration(labelText: 'Band Type'),
                        items: const [
                          DropdownMenuItem(value: 'fixed', child: Text('Fixed')),
                          DropdownMenuItem(value: 'floating', child: Text('Floating')),
                        ],
                        onChanged: (v) => setState(() => bandType = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: outsidePolicy,
                        decoration: const InputDecoration(labelText: 'Outside Policy'),
                        items: const [
                          DropdownMenuItem(value: 'block', child: Text('Block')),
                          DropdownMenuItem(value: 'allow_flag', child: Text('Allow & Flag')),
                        ],
                        onChanged: (v) => setState(() => outsidePolicy = v!),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(labelText: 'Outside Message'),
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
  }

  Future<void> _saveProfile() async {
    if (inLocation == null || outLocation == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tap map to pick both locations')));
      return;
    }

    final checkIn = GeofenceLocation(
      lat: inLocation!.latitude,
      lng: inLocation!.longitude,
      radius: inRadius,
    );
    final checkOut = GeofenceLocation(
      lat: outLocation!.latitude,
      lng: outLocation!.longitude,
      radius: outRadius,
    );

    final profile = GeofenceProfile(
      checkInLocation: checkIn,
      checkOutLocation: checkOut,
      bandType: bandType,
      outsidePolicy: outsidePolicy,
      outsideMessage: messageController.text.isNotEmpty ? messageController.text : null,
    );

    await GeofenceService.instance.setProfile(
      studentId: widget.studentId,
      dateId: widget.dateId,
      profile: profile,
    );

    if (mounted) Navigator.pop(context);
  }
}
