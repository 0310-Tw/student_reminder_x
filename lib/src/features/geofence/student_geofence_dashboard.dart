import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:students_reminder/src/features/geofence/geofence_service.dart';

import '../../shared/routes.dart';

class StudentGeofenceDashboard extends StatefulWidget {
  const StudentGeofenceDashboard({Key? key}) : super(key: key);

  @override
  State<StudentGeofenceDashboard> createState() =>
      _StudentGeofenceDashboardState();
}

class _StudentGeofenceDashboardState extends State<StudentGeofenceDashboard> {
  final GeofenceService _geofenceService = GeofenceService();

  Position? _currentPosition;
  Map<String, dynamic>? _geofenceProfile;
  Map<String, dynamic>? _locationStatus;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      // Get current position
      _currentPosition = await _geofenceService.getCurrentLocation();

      // Get today's geofence profile
      _geofenceProfile = await _geofenceService.getTodayGeofenceProfile();

      // Get location status
      if (_currentPosition != null) {
        _locationStatus = await _geofenceService.getLocationStatus();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load geofence data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshLocation() async {
    await _initializeData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofence Attendance'),
        actions: [
          IconButton(
            onPressed: _refreshLocation,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorWidget()
          : _buildContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshLocation,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_geofenceProfile == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_disabled, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No geofence profile found for today',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Contact your administrator to set up geofencing',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentLocationCard(),
          const SizedBox(height: 16),
          _buildGeofenceStatusCard(),
          const SizedBox(height: 16),
          // _buildCheckInOutButtons(),
          const SizedBox(height: 16),
          _buildLocationScheduleButton(),
          const SizedBox(height: 16),
          _buildIncidentHistoryButton(),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.my_location,
                  color: Colors.blue.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Current Location',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentPosition != null) ...[
              _buildLocationDetailRow(
                'Latitude',
                _currentPosition!.latitude.toStringAsFixed(6),
              ),
              _buildLocationDetailRow(
                'Longitude',
                _currentPosition!.longitude.toStringAsFixed(6),
              ),
              _buildLocationDetailRow(
                'Accuracy',
                '${_currentPosition!.accuracy.toStringAsFixed(1)} meters',
              ),
              _buildLocationDetailRow(
                'Updated',
                TimeOfDay.fromDateTime(DateTime.now()).format(context),
              ),
            ] else
              const Text('Location not available'),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildGeofenceStatusCard() {
    if (_locationStatus == null) return const SizedBox.shrink();

    final checkInDistance = _locationStatus!['checkInDistance'] as double?;
    final checkOutDistance = _locationStatus!['checkOutDistance'] as double?;
    final canCheckIn = _locationStatus!['canCheckIn'] as bool? ?? false;
    final canCheckOut = _locationStatus!['canCheckOut'] as bool? ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.green.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Geofence Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (checkInDistance != null) ...[
              _buildGeofenceZoneStatus(
                'Check-in Zone',
                checkInDistance,
                canCheckIn,
                _geofenceProfile!['checkInLocation']?['radius']?.toDouble() ??
                    50.0,
              ),
            ],
            if (checkOutDistance != null) ...[
              const SizedBox(height: 8),
              _buildGeofenceZoneStatus(
                'Check-out Zone',
                checkOutDistance,
                canCheckOut,
                _geofenceProfile!['checkOutLocation']?['radius']?.toDouble() ??
                    50.0,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeofenceZoneStatus(
    String zoneName,
    double distance,
    bool canAccess,
    double radius,
  ) {
    final isInsideZone = distance <= radius;
    final statusColor = canAccess
        ? Colors.green
        : (isInsideZone ? Colors.orange : Colors.red);
    final statusIcon = canAccess
        ? Icons.check_circle
        : (isInsideZone ? Icons.warning : Icons.cancel);
    final statusText = canAccess
        ? 'Available'
        : (isInsideZone ? 'In Zone' : 'Outside Zone');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                zoneName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Distance: ${distance.toStringAsFixed(1)}m (Radius: ${radius.toStringAsFixed(1)}m)',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Widget _buildCheckInOutButtons() {
  //   final canCheckIn = _locationStatus?['canCheckIn'] as bool? ?? false;
  //   final canCheckOut = _locationStatus?['canCheckOut'] as bool? ?? false;

  //   return Card(
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             children: [
  //               Icon(
  //                 Icons.access_time,
  //                 color: Colors.blue.withValues(alpha: 0.7),
  //               ),
  //               const SizedBox(width: 8),
  //               const Text(
  //                 'Attendance Actions',
  //                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 16),
  //           Row(
  //             children: [
  //               Expanded(
  //                 child: ElevatedButton.icon(
  //                   onPressed: (canCheckIn && !_isCheckingIn)
  //                       ? _handleCheckIn
  //                       : null,
  //                   icon: _isCheckingIn
  //                       ? const SizedBox(
  //                           width: 16,
  //                           height: 16,
  //                           child: CircularProgressIndicator(strokeWidth: 2),
  //                         )
  //                       : const Icon(Icons.login),
  //                   label: Text(_isCheckingIn ? 'Checking In...' : 'Check In'),
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: canCheckIn ? Colors.green : Colors.grey,
  //                     foregroundColor: Colors.white,
  //                     padding: const EdgeInsets.symmetric(vertical: 12),
  //                   ),
  //                 ),
  //               ),
  //               const SizedBox(width: 12),
  //               Expanded(
  //                 child: ElevatedButton.icon(
  //                   onPressed: (canCheckOut && !_isCheckingIn)
  //                       ? _handleCheckOut
  //                       : null,
  //                   icon: _isCheckingIn
  //                       ? const SizedBox(
  //                           width: 16,
  //                           height: 16,
  //                           child: CircularProgressIndicator(strokeWidth: 2),
  //                         )
  //                       : const Icon(Icons.logout),
  //                   label: Text(
  //                     _isCheckingIn ? 'Checking Out...' : 'Check Out',
  //                   ),
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: canCheckOut
  //                         ? Colors.orange
  //                         : Colors.grey,
  //                     foregroundColor: Colors.white,
  //                     padding: const EdgeInsets.symmetric(vertical: 12),
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //           if (!canCheckIn && !canCheckOut) ...[
  //             const SizedBox(height: 8),
  //             Container(
  //               width: double.infinity,
  //               padding: const EdgeInsets.all(12),
  //               decoration: BoxDecoration(
  //                 color: Colors.amber.withValues(alpha: 0.1),
  //                 borderRadius: BorderRadius.circular(8),
  //                 border: Border.all(
  //                   color: Colors.amber.withValues(alpha: 0.3),
  //                 ),
  //               ),
  //               child: Row(
  //                 children: [
  //                   Icon(Icons.info, color: Colors.amber.shade700, size: 20),
  //                   const SizedBox(width: 8),at
  //                   const Expanded(
  //                     child: Text(
  //                       'Move closer to a check-in or check-out zone to enable attendance actions',
  //                       style: TextStyle(fontSize: 12),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ],
  //       ),
  //     ),
  //   );

  Widget _buildLocationScheduleButton() {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.schedule,
          color: Colors.orange.withValues(alpha: 0.7),
        ),
        title: const Text('Weekly Location Schedule'),
        subtitle: const Text('Set your campus locations for each day'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.locationSelection);
        },
      ),
    );
  }

  Widget _buildIncidentHistoryButton() {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.history,
          color: Colors.purple.withValues(alpha: 0.7),
        ),
        title: const Text('View Incident History'),
        subtitle: const Text('See your geofence violation records'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.geofenceIncidents);
        },
      ),
    );
  }
}