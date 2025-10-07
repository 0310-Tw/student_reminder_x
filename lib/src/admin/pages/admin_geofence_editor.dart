import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comprehensive_geofence_resolver.dart';

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
  LatLng? selectedLocation;
  double radius = 100;
  Set<Marker> markers = {};
  bool isLoading = true;
  Map<String, dynamic>? existingLocation;
  GeofenceBandType bandType = GeofenceBandType.fixed;
  String outsideAreaMessage = '';
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _loadExistingLocation();
    _loadStudentCustomLocations();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingLocation() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .collection('geofence_profiles')
          .doc(widget.dateId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          existingLocation = data;
          selectedLocation = LatLng(
            data['latitude']?.toDouble() ?? 18.0179,
            data['longitude']?.toDouble() ?? -76.8099,
          );
          radius = data['radius']?.toDouble() ?? 100.0;

          // Load band type and outside area message
          String? bandTypeString = data['bandType']?.toString();
          bandType = bandTypeString?.toLowerCase() == 'floating'
              ? GeofenceBandType.floating
              : GeofenceBandType.fixed;
          outsideAreaMessage = data['outsideAreaMessage']?.toString() ?? '';
          _messageController.text = outsideAreaMessage;
        });
      }
    } catch (e) {
      print('Error loading existing location: $e');
    }
  }

  Future<void> _loadStudentCustomLocations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .collection('geofence_profiles')
          .get();

      Set<Marker> studentMarkers = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['source'] == 'studentCustom') {
          final lat = data['latitude']?.toDouble();
          final lng = data['longitude']?.toDouble();
          final description = data['description'] ?? 'Student Location';

          if (lat != null && lng != null) {
            studentMarkers.add(
              Marker(
                markerId: MarkerId('student_${doc.id}'),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: _formatDay(doc.id),
                  snippet: description,
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
              ),
            );
          }
        }
      }

      setState(() {
        markers = studentMarkers;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading student locations: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        title: Text('Set Location - ${_formatDay(widget.dateId)}'),
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Instructions
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap on the map to set a new location for ${_formatDay(widget.dateId)}. Blue markers show other student custom locations.',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Map
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: selectedLocation ?? LatLng(18.0179, -76.8099),
                      zoom: 14,
                    ),
                    markers: {
                      ...markers, // Student's other custom locations
                      if (selectedLocation != null)
                        Marker(
                          markerId: const MarkerId('selected'),
                          position: selectedLocation!,
                          infoWindow: InfoWindow(
                            title: 'New Location',
                            snippet:
                                'Selected location for ${_formatDay(widget.dateId)}',
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                        ),
                    },
                    circles: selectedLocation != null
                        ? {
                            Circle(
                              circleId: CircleId('geofence'),
                              center: selectedLocation!,
                              radius: radius,
                              fillColor: Colors.green.withOpacity(0.2),
                              strokeColor: Colors.green,
                              strokeWidth: 2,
                            ),
                          }
                        : {},
                    onTap: (pos) {
                      setState(() {
                        selectedLocation = pos;
                      });
                    },
                  ),
                ),

                // Controls
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Radius: ${radius.toInt()}m',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Slider(
                                  value: radius,
                                  min: 50,
                                  max: 500,
                                  divisions: 18,
                                  onChanged: (value) {
                                    setState(() {
                                      radius = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Band Type Selection
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Band Type:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<GeofenceBandType>(
                                value: bandType,
                                isExpanded: true,
                                onChanged: (GeofenceBandType? newValue) {
                                  setState(() {
                                    bandType = newValue!;
                                  });
                                },
                                items: [
                                  DropdownMenuItem<GeofenceBandType>(
                                    value: GeofenceBandType.fixed,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Fixed Band',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Must be within designated geofence',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem<GeofenceBandType>(
                                    value: GeofenceBandType.floating,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Floating Band',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'May clock in/out anywhere',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Outside Area Message
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Outside Area Message:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _messageController,
                            onChanged: (value) {
                              outsideAreaMessage = value;
                            },
                            decoration: InputDecoration(
                              hintText:
                                  'Custom message when student is outside area',
                              border: OutlineInputBorder(),
                              helperText:
                                  'Shown when student tries to clock in/out outside designated area',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: selectedLocation == null
                                  ? null
                                  : _saveLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF2C3E50),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                existingLocation != null
                                    ? 'Update Location'
                                    : 'Save Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _saveLocation() async {
    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location on the map')),
      );
      return;
    }

    try {
      // Save to the users/{userId}/geofence_profiles/{day} collection
      // This matches the format expected by the enhanced geofence page
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .collection('geofence_profiles')
          .doc(widget.dateId)
          .set({
            'dayOfWeek': widget.dateId,
            'latitude': selectedLocation!.latitude,
            'longitude': selectedLocation!.longitude,
            'radius': radius,
            'description': 'Custom location for ${_formatDay(widget.dateId)}',
            'isEnabled': true,
            'source': 'studentCustom',
            'bandType': bandType == GeofenceBandType.floating
                ? 'floating'
                : 'fixed',
            'outsideAreaMessage': outsideAreaMessage.trim().isEmpty
                ? null
                : outsideAreaMessage.trim(),
            'lastModified': FieldValue.serverTimestamp(),
            'modifiedBy': 'admin_override',
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Return true to indicate success
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDay(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 'Monday';
      case 'tuesday':
        return 'Tuesday';
      case 'wednesday':
        return 'Wednesday';
      case 'thursday':
        return 'Thursday';
      case 'friday':
        return 'Friday';
      default:
        return day;
    }
  }
}
