import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:students_reminder/src/features/geofence/geofence_service.dart';

import '../../shared/routes.dart';

class GeofenceIncidentHistory extends StatefulWidget {
  const GeofenceIncidentHistory({Key? key}) : super(key: key);

  @override
  State<GeofenceIncidentHistory> createState() =>
      _GeofenceIncidentHistoryState();
}

class _GeofenceIncidentHistoryState extends State<GeofenceIncidentHistory> {
  final GeofenceService _geofenceService = GeofenceService();

  List<Map<String, dynamic>> _incidents = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Listen to the simplified stream (server-side filtering by studentId only)
      final stream = _geofenceService.getStudentIncidentsWithDateFilter(
        _startDate,
        _endDate,
      );

      final snapshot = await stream.first;
      final allIncidents = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Convert Timestamp to DateTime if needed
        if (data['createdAt'] != null) {
          data['timestamp'] = (data['createdAt'] as dynamic).toDate();
        }
        return data;
      }).toList();

      // Client-side date filtering
      final filteredIncidents = allIncidents.where((incident) {
        final timestamp = incident['timestamp'] as DateTime?;
        if (timestamp == null) return false;

        return timestamp.isAfter(
              _startDate.subtract(const Duration(days: 1)),
            ) &&
            timestamp.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      setState(() {
        _incidents = filteredIncidents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load incidents: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadIncidents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofence Incidents'),
        actions: [
          IconButton(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range),
            tooltip: 'Filter by date range',
          ),
          IconButton(
            onPressed: _loadIncidents,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.locationSelection),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Update Location Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorWidget()
          : _buildIncidentsList(),
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
            onPressed: _loadIncidents,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentsList() {
    if (_incidents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'No geofence incidents found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep it up! No violations in the selected period.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _buildDateRangeChip(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.locationSelection),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Set Up Your Locations'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSummaryCard(),
        _buildDateRangeChip(),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _incidents.length,
            itemBuilder: (context, index) =>
                _buildIncidentCard(_incidents[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    if (_incidents.isEmpty) return const SizedBox.shrink();

    final totalIncidents = _incidents.length;
    final uniqueDays = _incidents
        .map((incident) {
          final timestamp = incident['timestamp'] as DateTime?;
          if (timestamp != null) {
            return DateFormat('yyyy-MM-dd').format(timestamp);
          }
          return '';
        })
        .where((date) => date.isNotEmpty)
        .toSet()
        .length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red.shade700, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalIncidents Incident${totalIncidents == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Across $uniqueDays day${uniqueDays == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeChip() {
    final dateFormatter = DateFormat('MMM d');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(
              '${dateFormatter.format(_startDate)} - ${dateFormatter.format(_endDate)}',
            ),
            onPressed: _selectDateRange,
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    final timestamp = incident['timestamp'] as DateTime?;
    final action = incident['action'] as String? ?? 'Unknown';
    final distance = (incident['distance'] as num?)?.toDouble() ?? 0.0;
    final targetLocation = incident['targetLocation'] as Map<String, dynamic>?;
    final userLocation = incident['userLocation'] as Map<String, dynamic>?;

    final dateStr = timestamp != null
        ? DateFormat('MMM d, y').format(timestamp)
        : 'Unknown date';
    final timeStr = timestamp != null
        ? DateFormat('h:mm a').format(timestamp)
        : 'Unknown time';

    Color actionColor = Colors.grey;
    IconData actionIcon = Icons.help_outline;
    String actionText = action;

    switch (action.toLowerCase()) {
      case 'checkin':
        actionColor = Colors.blue;
        actionIcon = Icons.login;
        actionText = 'Check-in Violation';
        break;
      case 'checkout':
        actionColor = Colors.orange;
        actionIcon = Icons.logout;
        actionText = 'Check-out Violation';
        break;
      case 'monitoring':
        actionColor = Colors.red;
        actionIcon = Icons.location_off;
        actionText = 'Location Monitoring';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(actionIcon, color: actionColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actionText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$dateStr at $timeStr',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${distance.toStringAsFixed(1)}m',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (targetLocation != null) ...[
              const SizedBox(height: 12),
              _buildLocationDetails(targetLocation, userLocation),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDetails(
    Map<String, dynamic> targetLocation,
    Map<String, dynamic>? userLocation,
  ) {
    final targetLat = targetLocation['lat']?.toString() ?? 'N/A';
    final targetLng = targetLocation['lng']?.toString() ?? 'N/A';
    final radius = (targetLocation['radius'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Target Location',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Lat: ${double.tryParse(targetLat)?.toStringAsFixed(6) ?? targetLat}',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          Text(
            'Lng: ${double.tryParse(targetLng)?.toStringAsFixed(6) ?? targetLng}',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          Text(
            'Radius: ${radius.toStringAsFixed(1)}m',
            style: const TextStyle(fontSize: 11),
          ),
          if (userLocation != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.my_location, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Your Location',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Lat: ${(userLocation['lat'] as num?)?.toStringAsFixed(6) ?? 'N/A'}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
            Text(
              'Lng: ${(userLocation['lng'] as num?)?.toStringAsFixed(6) ?? 'N/A'}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }
}
