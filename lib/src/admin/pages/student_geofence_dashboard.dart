import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:students_reminder/src/services/geofence_service.dart';
import 'package:students_reminder/src/services/helper.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/shared/routes.dart';
import 'package:students_reminder/src/admin/models/geofence_profile.dart';

class StudentGeofenceDashboard extends StatefulWidget {
  const StudentGeofenceDashboard({super.key});

  @override
  State<StudentGeofenceDashboard> createState() =>
      _StudentGeofenceDashboardState();
}

class _StudentGeofenceDashboardState extends State<StudentGeofenceDashboard> {
  final GeofenceService _geofenceService = GeofenceService.instance;

  Position? _currentPosition;
  GeofenceProfile? _geofenceProfile;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;
  double? _checkInDistance;
  double? _checkOutDistance;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = AuthService.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      _currentPosition = await _geofenceService.getCurrentLocation();

      final now = DateTime.now();
      final dateId =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      _geofenceProfile =
          await _geofenceService.getProfile(user.uid, dateId) ??
              _geofenceService.getDefaultProfileForDay(now);

      // Compute distances
      if (_geofenceProfile != null && _currentPosition != null) {
        _checkInDistance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          _geofenceProfile!.inLat,
          _geofenceProfile!.inLng,
        );

        _checkOutDistance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          _geofenceProfile!.outLat,
          _geofenceProfile!.outLng,
        );
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCheckAction(String actionType) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      _showError('User not authenticated');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      final dateId =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final canProceed = await handleClockAction(
        context: context,
        studentId: user.uid,
        dayId: dateId,
        actionType: actionType,
      );

      if (canProceed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${actionType == 'checkin' ? 'Check-in' : 'Check-out'} successful!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _initializeData();
      } else {
        _showError('Action blocked due to geofence policy.');
      }
    } catch (e) {
      _showError('Failed to perform action: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofence Dashboard'),
        actions: [
          IconButton(
            onPressed: _initializeData,
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
          Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'Unknown error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_geofenceProfile == null || _currentPosition == null) {
      return const Center(
        child: Text('No geofence data available'),
      );
    }

    final inRadius = _geofenceProfile!.inRadius;
    final outRadius = _geofenceProfile!.outRadius;

    final inInside = (_checkInDistance ?? double.infinity) <= inRadius;
    final outInside = (_checkOutDistance ?? double.infinity) <= outRadius;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildLocationCard(),
          const SizedBox(height: 16),
          _buildZoneCard('Check-in Zone', _checkInDistance, inRadius, inInside),
          const SizedBox(height: 8),
          _buildZoneCard(
              'Check-out Zone', _checkOutDistance, outRadius, outInside),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  onPressed: (!_isProcessing && inInside)
                      ? () => _handleCheckAction('checkin')
                      : null,
                  label: const Text('Check In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: inInside ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                  onPressed: (!_isProcessing && outInside)
                      ? () => _handleCheckAction('checkout')
                      : null,
                  label: const Text('Check Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: outInside ? Colors.orange : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Location',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text('Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}'),
            Text('Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
            Text('Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(1)}m'),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneCard(
      String title, double? distance, double radius, bool inside) {
    final color = inside ? Colors.green : Colors.red;
    final icon = inside ? Icons.check_circle : Icons.cancel;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(
          'Distance: ${distance?.toStringAsFixed(1) ?? '-'}m (Radius: ${radius.toStringAsFixed(1)}m)',
        ),
        trailing: Text(
          inside ? 'Inside' : 'Outside',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule, color: Colors.orange),
            title: const Text('Weekly Location Schedule'),
            subtitle: const Text('Set your campus locations for each day'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.locationSelection),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history, color: Colors.purple),
            title: const Text('Geofence Incident History'),
            subtitle: const Text('View previous geofence violations'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.geofenceIncidents),
          ),
        ),
      ],
    );
  }
}
