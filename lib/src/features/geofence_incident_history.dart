import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/geofence_service.dart';
import 'package:students_reminder/src/shared/routes.dart';

class GeofenceIncidentHistory extends StatefulWidget {
  const GeofenceIncidentHistory({Key? key}) : super(key: key);

  @override
  State<GeofenceIncidentHistory> createState() =>
      _GeofenceIncidentHistoryState();
}

class _GeofenceIncidentHistoryState extends State<GeofenceIncidentHistory> {
  final GeofenceService _geofenceService = GeofenceService.instance;

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
      final stream = _geofenceService.getStudentIncidentsWithDateFilter(
        _startDate,
        _endDate,
      );

      final snapshot = await stream.first;
      final allIncidents = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['timestamp'] is Timestamp) {
          data['timestamp'] = (data['timestamp'] as Timestamp).toDate();
        }
        return data;
      }).toList();

      final filtered = allIncidents.where((incident) {
        final timestamp = incident['timestamp'] as DateTime?;
        if (timestamp == null) return false;
        return timestamp.isAfter(_startDate.subtract(const Duration(days: 1))) &&
               timestamp.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      setState(() {
        _incidents = filtered;
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
          ),
          IconButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.locationSelection),
            icon: const Icon(Icons.settings_outlined),
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
          Icon(Icons.error_outline, size: 64, color: Colors.red.withOpacity(0.7)),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Unknown error',
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
            Icon(Icons.check_circle_outline,
                size: 64, color: Colors.green.withOpacity(0.7)),
            const SizedBox(height: 16),
            const Text('No geofence incidents found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    final total = _incidents.length;
    final uniqueDays = _incidents
        .map((i) => DateFormat('yyyy-MM-dd').format(i['timestamp'] as DateTime))
        .toSet()
        .length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
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
                  '$total Incident${total == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('Across $uniqueDays day${uniqueDays == 1 ? '' : 's'}',
                    style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeChip() {
    final df = DateFormat('MMM d');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ActionChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text('${df.format(_startDate)} - ${df.format(_endDate)}'),
          onPressed: _selectDateRange,
        ),
      ]),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    final timestamp = incident['timestamp'] as DateTime?;
    final action = incident['type'] as String? ?? 'Unknown';
    final distance = (incident['distanceMeters'] as num?)?.toDouble() ?? 0.0;
    final dateStr =
        timestamp != null ? DateFormat('MMM d, y').format(timestamp) : 'Unknown';
    final timeStr =
        timestamp != null ? DateFormat('h:mm a').format(timestamp) : '';

    Color color = Colors.grey;
    IconData icon = Icons.help_outline;
    String title = 'Incident';

    switch (action.toLowerCase()) {
      case 'checkin':
        color = Colors.blue;
        icon = Icons.login;
        title = 'Check-in Violation';
        break;
      case 'checkout':
        color = Colors.orange;
        icon = Icons.logout;
        title = 'Check-out Violation';
        break;
      default:
        color = Colors.red;
        icon = Icons.warning;
        title = 'Geofence Violation';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  Text('$dateStr at $timeStr',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 14)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${distance.toStringAsFixed(1)}m',
                  style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 12)),
            ),
          ]),
        ]),
      ),
    );
  }
}
