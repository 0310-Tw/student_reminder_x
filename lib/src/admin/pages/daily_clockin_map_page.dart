import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class DailyClockInMapPage extends StatefulWidget {
  final DateTime selectedDate;

  const DailyClockInMapPage({super.key, required this.selectedDate});

  @override
  State<DailyClockInMapPage> createState() => _DailyClockInMapPageState();
}

class _DailyClockInMapPageState extends State<DailyClockInMapPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _clockInData = [];
  List<Map<String, dynamic>> _historicalData = [];
  bool _isLoading = true;
  bool _showHistorical = true;

  // Default camera position (Up Park Camp)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(18.0123, -76.7890),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _loadClockInData();
  }

  Future<void> _loadClockInData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Format the date to match the document ID format
      String dateId = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

      // Get all users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      List<Map<String, dynamic>> clockInEntries = [];
      Set<Marker> markers = {};

      // Get date range for historical data (past 7 days)
      List<String> historicalDates = [];
      for (int i = 1; i <= 7; i++) {
        final pastDate = widget.selectedDate.subtract(Duration(days: i));
        historicalDates.add(DateFormat('yyyy-MM-dd').format(pastDate));
      }

      print('Looking for attendance data for date: $dateId');
      print('Also loading historical data for: $historicalDates');
      print('Found ${usersSnapshot.docs.length} students');

      for (var userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final studentName =
              '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                  .trim();
          print('Checking attendance for: $studentName (${userDoc.id})');

          // Get attendance data for this date - correct path structure
          final attendanceDoc = await FirebaseFirestore.instance
              .collection('attendance')
              .doc(userDoc.id)
              .collection('days')
              .doc(dateId)
              .get();

          print(
            'Attendance doc exists for $studentName: ${attendanceDoc.exists}',
          );
          if (attendanceDoc.exists) {
            final attendanceData = attendanceDoc.data()!;
            print('Attendance data for $studentName: $attendanceData');

            // Check if there's a clock-in time and location
            final clockInTime = attendanceData['inAt'] as Timestamp?;

            // Try multiple possible location field formats
            double? latitude, longitude;
            String? address = 'Unknown Location';

            // Check for inLoc GeoPoint
            if (attendanceData['inLoc'] != null) {
              final geoPoint = attendanceData['inLoc'] as GeoPoint;
              latitude = geoPoint.latitude;
              longitude = geoPoint.longitude;
            }
            // Check for individual lat/lng fields
            else if (attendanceData['inLat'] != null &&
                attendanceData['inLng'] != null) {
              latitude = (attendanceData['inLat'] as num).toDouble();
              longitude = (attendanceData['inLng'] as num).toDouble();
            }

            // Get place name
            if (attendanceData['placeIn'] != null) {
              address = attendanceData['placeIn'] as String;
            } else if (attendanceData['inPlace'] != null) {
              address = attendanceData['inPlace'] as String;
            }

            if (latitude != null && longitude != null && clockInTime != null) {
              final userData = userDoc.data();
              final studentName =
                  '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                      .trim();

              final clockInEntry = {
                'userId': userDoc.id,
                'studentName': studentName,
                'email': userData['email'] ?? '',
                'latitude': latitude,
                'longitude': longitude,
                'clockInTime': clockInTime,
                'address': address,
                'status': attendanceData['status'] ?? 'present',
              };

              clockInEntries.add(clockInEntry);

              // Create marker for this student
              final marker = Marker(
                markerId: MarkerId(userDoc.id),
                position: LatLng(latitude, longitude),
                infoWindow: InfoWindow(
                  title: studentName,
                  snippet: 'Clocked in at ${_formatTime(clockInTime)}',
                  onTap: () => _showStudentDetails(clockInEntry),
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  _getMarkerColor(clockInTime),
                ),
              );

              markers.add(marker);
            }
          }

          // Load historical data for this student if _showHistorical is true
          if (_showHistorical) {
            await _loadHistoricalDataForStudent(
              userDoc,
              historicalDates,
              markers,
              studentName,
              userData,
            );
          }
        } catch (e) {
          print('Error loading attendance for user ${userDoc.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _clockInData = clockInEntries;
          _markers = markers;
          _isLoading = false;
        });
      }

      print(
        'Loaded ${clockInEntries.length} current day entries and ${_historicalData.length} historical entries',
      );

      // Adjust camera to show all markers if we have data
      if (markers.isNotEmpty && _mapController != null) {
        _fitMarkersInView();
      }
    } catch (e) {
      print('Error loading clock-in data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading clock-in data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _getMarkerColor(Timestamp clockInTime) {
    final clockInHour = clockInTime.toDate().hour;

    // Green for early (before 8 AM)
    if (clockInHour < 8) return BitmapDescriptor.hueGreen;

    // Blue for on time (8-9 AM)
    if (clockInHour < 9) return BitmapDescriptor.hueBlue;

    // Orange for late (9-10 AM)
    if (clockInHour < 10) return BitmapDescriptor.hueOrange;

    // Red for very late (after 10 AM)
    return BitmapDescriptor.hueRed;
  }

  void _fitMarkersInView() {
    if (_markers.isEmpty || _mapController == null) return;

    final bounds = _calculateBounds(_markers);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  LatLngBounds _calculateBounds(Set<Marker> markers) {
    double minLat = markers.first.position.latitude;
    double maxLat = markers.first.position.latitude;
    double minLng = markers.first.position.longitude;
    double maxLng = markers.first.position.longitude;

    for (final marker in markers) {
      minLat = math.min(minLat, marker.position.latitude);
      maxLat = math.max(maxLat, marker.position.latitude);
      minLng = math.min(minLng, marker.position.longitude);
      maxLng = math.max(maxLng, marker.position.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  String _formatTime(Timestamp timestamp) {
    return DateFormat('h:mm a').format(timestamp.toDate());
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEEE, MMM d, yyyy').format(date);
  }

  void _showStudentDetails(Map<String, dynamic> clockInEntry) {
    final status = clockInEntry['status'] as String? ?? 'present';
    Color statusColor = _getStatusColor(status);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clockInEntry['studentName']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.email, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(child: Text(clockInEntry['email'])),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  'Clocked in at ${_formatTime(clockInEntry['clockInTime'])}',
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: statusColor),
                SizedBox(width: 8),
                Text(
                  'Status: ${status.toUpperCase()}',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(child: Text(clockInEntry['address'])),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.gps_fixed, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${clockInEntry['latitude'].toStringAsFixed(6)}, ${clockInEntry['longitude'].toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _centerOnStudent(clockInEntry);
            },
            child: Text('Center on Map'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'early':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _centerOnStudent(Map<String, dynamic> clockInEntry) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(clockInEntry['latitude'], clockInEntry['longitude']),
          16.0,
        ),
      );
    }
  }

  Future<void> _loadHistoricalDataForStudent(
    QueryDocumentSnapshot<Map<String, dynamic>> userDoc,
    List<String> historicalDates,
    Set<Marker> markers,
    String studentName,
    Map<String, dynamic> userData,
  ) async {
    for (String historicalDateId in historicalDates) {
      try {
        final historicalDoc = await FirebaseFirestore.instance
            .collection('attendance')
            .doc(userDoc.id)
            .collection('days')
            .doc(historicalDateId)
            .get();

        if (historicalDoc.exists) {
          final attendanceData = historicalDoc.data()!;
          final clockInTime = attendanceData['inAt'] as Timestamp?;

          // Try multiple possible location field formats
          double? latitude, longitude;

          // Check for inLoc GeoPoint
          if (attendanceData['inLoc'] != null) {
            final geoPoint = attendanceData['inLoc'] as GeoPoint;
            latitude = geoPoint.latitude;
            longitude = geoPoint.longitude;
          }
          // Check for individual lat/lng fields
          else if (attendanceData['inLat'] != null &&
              attendanceData['inLng'] != null) {
            latitude = (attendanceData['inLat'] as num).toDouble();
            longitude = (attendanceData['inLng'] as num).toDouble();
          }

          if (latitude != null && longitude != null && clockInTime != null) {
            // Add historical marker entry
            _historicalData.add({
              'userId': userDoc.id,
              'studentName': studentName,
              'email': userData['email'] ?? '',
              'latitude': latitude,
              'longitude': longitude,
              'clockInTime': clockInTime,
              'date': historicalDateId,
              'isHistorical': true,
            });

            // Create dimmed marker for historical data
            final historicalMarker = Marker(
              markerId: MarkerId('${userDoc.id}_$historicalDateId'),
              position: LatLng(latitude, longitude),
              alpha: 0.4, // Make it semi-transparent
              infoWindow: InfoWindow(
                title: '$studentName (${_formatDateShort(historicalDateId)})',
                snippet: 'Historical: ${_formatTime(clockInTime)}',
                onTap: () => _showHistoricalDetails({
                  'userId': userDoc.id,
                  'studentName': studentName,
                  'email': userData['email'] ?? '',
                  'latitude': latitude,
                  'longitude': longitude,
                  'clockInTime': clockInTime,
                  'date': historicalDateId,
                  'address':
                      attendanceData['placeIn'] ??
                      attendanceData['inPlace'] ??
                      'Unknown Location',
                  'status': attendanceData['status'] ?? 'present',
                }),
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet, // Use violet for historical markers
              ),
            );

            markers.add(historicalMarker);
          }
        }
      } catch (e) {
        print(
          'Error loading historical data for ${userDoc.id} on $historicalDateId: $e',
        );
      }
    }
  }

  String _formatDateShort(String dateId) {
    try {
      final date = DateTime.parse(dateId);
      return DateFormat('MMM d').format(date);
    } catch (e) {
      return dateId;
    }
  }

  void _showHistoricalDetails(Map<String, dynamic> historicalEntry) {
    final date = historicalEntry['date'] as String;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${historicalEntry['studentName']} - Historical'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text('Date: ${_formatDateFromId(date)}'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  'Clocked in at ${_formatTime(historicalEntry['clockInTime'])}',
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(historicalEntry['address'] ?? 'Unknown Location'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _centerOnStudent(historicalEntry);
            },
            child: Text('Center on Map'),
          ),
        ],
      ),
    );
  }

  String _formatDateFromId(String dateId) {
    try {
      final date = DateTime.parse(dateId);
      return DateFormat('EEEE, MMM d, yyyy').format(date);
    } catch (e) {
      return dateId;
    }
  }

  void _toggleHistoricalView() {
    if (mounted) {
      setState(() {
        _showHistorical = !_showHistorical;
      });
      _loadClockInData(); // Reload data with new setting
    }
  }

  Widget _buildLegendItem(String label, Color color, bool isTransparent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isTransparent ? color.withOpacity(0.4) : color,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Clock-In Locations'),
            Text(
              _formatDate(widget.selectedDate),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showHistorical ? Icons.visibility : Icons.visibility_off,
            ),
            tooltip: _showHistorical
                ? 'Hide Historical Locations'
                : 'Show Historical Locations',
            onPressed: _toggleHistoricalView,
          ),
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadClockInData),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading clock-in locations...'),
                ],
              ),
            )
          : Column(
              children: [
                // Summary Bar
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Total Students',
                        '${_clockInData.length}',
                        Icons.people,
                        Colors.blue,
                      ),
                      _buildSummaryItem(
                        'Early (< 8 AM)',
                        '${_clockInData.where((e) => (e['clockInTime'] as Timestamp).toDate().hour < 8).length}',
                        Icons.trending_up,
                        Colors.green,
                      ),
                      _buildSummaryItem(
                        'Late (> 9 AM)',
                        '${_clockInData.where((e) => (e['clockInTime'] as Timestamp).toDate().hour >= 9).length}',
                        Icons.trending_down,
                        Colors.red,
                      ),
                      if (_showHistorical)
                        _buildSummaryItem(
                          'Historical',
                          '${_historicalData.length}',
                          Icons.history,
                          Colors.purple,
                        ),
                    ],
                  ),
                ),

                // Legend
                if (_clockInData.isNotEmpty ||
                    (_showHistorical && _historicalData.isNotEmpty))
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildLegendItem('Today', Colors.blue, false),
                        if (_showHistorical)
                          _buildLegendItem('Historical', Colors.purple, true),
                        _buildLegendItem('Early', Colors.green, false),
                        _buildLegendItem('Late', Colors.red, false),
                      ],
                    ),
                  ),

                // Map
                Expanded(
                  child: _clockInData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No clock-in locations found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'for ${_formatDate(widget.selectedDate)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : GoogleMap(
                          initialCameraPosition: _initialPosition,
                          markers: _markers,
                          onMapCreated: (GoogleMapController controller) {
                            _mapController = controller;
                            // Fit markers in view after map is created
                            if (_markers.isNotEmpty) {
                              Future.delayed(Duration(milliseconds: 500), () {
                                _fitMarkersInView();
                              });
                            }
                          },
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: true,
                          mapToolbarEnabled: false,
                        ),
                ),
              ],
            ),
      floatingActionButton: _clockInData.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _fitMarkersInView,
              backgroundColor: Color(0xFF2C3E50),
              icon: Icon(Icons.center_focus_strong, color: Colors.white),
              label: Text('Fit All', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}