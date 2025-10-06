import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/geofence_incident_models.dart';
import '../services/geofence_incident_service.dart';

/// Admin incidents list page with comprehensive filtering
class AdminIncidentsPage extends StatefulWidget {
  const AdminIncidentsPage({super.key});

  @override
  State<AdminIncidentsPage> createState() => _AdminIncidentsPageState();
}

class _AdminIncidentsPageState extends State<AdminIncidentsPage> {
  IncidentFilters _filters = const IncidentFilters();
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofence Incidents'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filters.hasActiveFilters,
              label: Text('${_filters.activeFiltersCount}'),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _showFiltersDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filters.hasActiveFilters) _buildActiveFiltersChips(),
          Expanded(
            child: StreamBuilder<List<GeofenceIncident>>(
              stream: GeofenceIncidentService.getIncidents(
                filters: _filters,
                limit: 100,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Error loading incidents: ${snapshot.error}'),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final incidents = snapshot.data ?? [];

                if (incidents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filters.hasActiveFilters
                              ? 'No incidents match the current filters'
                              : 'No geofence incidents recorded',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (_filters.hasActiveFilters) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _clearAllFilters(),
                            child: const Text('Clear Filters'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.separated(
                    itemCount: incidents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final incident = incidents[index];
                      return _buildIncidentCard(incident);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showIncidentStatistics(),
        child: const Icon(Icons.analytics),
        tooltip: 'View Statistics',
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        children: [
          if (_filters.dateRange != null)
            FilterChip(
              label: Text(
                '${_dateFormat.format(_filters.dateRange!.start)} - '
                '${_dateFormat.format(_filters.dateRange!.end)}',
              ),
              onSelected: (_) {},
              onDeleted: () => _updateFilter(dateRange: null),
            ),
          if (_filters.studentClass != null &&
              _filters.studentClass!.isNotEmpty)
            FilterChip(
              label: Text('Class: ${_filters.studentClass}'),
              onSelected: (_) {},
              onDeleted: () => _updateFilter(studentClass: null),
            ),
          if (_filters.bandType != null && _filters.bandType!.isNotEmpty)
            FilterChip(
              label: Text('Band: ${_filters.bandType?.toUpperCase()}'),
              onSelected: (_) {},
              onDeleted: () => _updateFilter(bandType: null),
            ),
          if (_filters.status != null && _filters.status!.isNotEmpty)
            FilterChip(
              label: Text('Status: ${_filters.status?.toUpperCase()}'),
              onSelected: (_) {},
              onDeleted: () => _updateFilter(status: null),
            ),
          if (_filters.direction != null && _filters.direction!.isNotEmpty)
            FilterChip(
              label: Text(
                'Direction: ${_filters.direction?.replaceAll('_', ' ')}',
              ),
              onSelected: (_) {},
              onDeleted: () => _updateFilter(direction: null),
            ),
          if (_filters.hasActiveFilters)
            ActionChip(
              label: const Text('Clear All'),
              onPressed: _clearAllFilters,
            ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(GeofenceIncident incident) {
    final isAcknowledged = incident.status == 'acknowledged';
    final isPending = incident.status == 'pending';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      elevation: isPending ? 4 : 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isPending
              ? Border.all(color: Colors.red.withOpacity(0.3), width: 2)
              : null,
        ),
        child: Column(
          children: [
            ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getIncidentStatusColor(incident),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        incident.direction == 'check_in'
                            ? Icons.login
                            : Icons.logout,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    if (isPending)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Icon(
                            Icons.priority_high,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${incident.studentName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _buildStatusBadge(incident.status),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.red[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${incident.formattedDistance} outside designated area',
                        style: TextStyle(
                          color: Colors.red[600],
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${_dateFormat.format(incident.occurredAt)} at ${_timeFormat.format(incident.occurredAt)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: incident.bandType == 'fixed'
                              ? Colors.red[100]
                              : Colors.blue[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          incident.bandType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: incident.bandType == 'fixed'
                                ? Colors.red[800]
                                : Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPending)
                    IconButton(
                      icon: Icon(Icons.check, color: Colors.green),
                      onPressed: () =>
                          _acknowledgeIncident(incident.id, incident.studentId),
                      tooltip: 'Acknowledge',
                    ),
                  IconButton(
                    icon: Icon(Icons.map, color: Colors.blue),
                    onPressed: () => _showIncidentLocation(incident),
                    tooltip: 'View Location',
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              onTap: () => _openIncidentDetail(incident),
            ),
            // Action buttons row
            if (isPending || isAcknowledged)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (isPending) ...[
                      _buildActionButton(
                        'Acknowledge',
                        Icons.check_circle,
                        Colors.green,
                        () => _acknowledgeIncident(
                          incident.id,
                          incident.studentId,
                        ),
                      ),
                      _buildActionButton(
                        'Message Student',
                        Icons.message,
                        Colors.blue,
                        () => _messageStudent(
                          incident.studentId,
                          incident.studentName,
                        ),
                      ),
                    ],
                    if (isAcknowledged) ...[
                      _buildActionButton(
                        'Resolve',
                        Icons.done_all,
                        Colors.purple,
                        () => _resolveIncident(incident.id, incident.studentId),
                      ),
                      _buildActionButton(
                        'Add Note',
                        Icons.note_add,
                        Colors.orange,
                        () => _addIncidentNote(incident),
                      ),
                    ],
                    _buildActionButton(
                      'View Map',
                      Icons.map_outlined,
                      Colors.indigo,
                      () => _showIncidentLocation(incident),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'acknowledged':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _updateFilter({
    DateTimeRange? dateRange,
    String? studentClass,
    String? bandType,
    String? status,
    String? direction,
  }) {
    setState(() {
      _filters = _filters.copyWith(
        dateRange: dateRange,
        studentClass: studentClass,
        bandType: bandType,
        status: status,
        direction: direction,
      );
    });
  }

  void _clearAllFilters() {
    setState(() {
      _filters = const IncidentFilters();
    });
  }

  void _showFiltersDialog() {
    showDialog(
      context: context,
      builder: (context) => _FiltersDialog(
        currentFilters: _filters,
        onFiltersChanged: (newFilters) {
          setState(() {
            _filters = newFilters;
          });
        },
      ),
    );
  }

  void _showQuickMapView(GeofenceIncident incident) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${incident.directionDisplay} Location'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: Column(
            children: [
              Text('Designated: ${incident.designatedLocation.coordinates}'),
              Text('Actual: ${incident.actualLocation.coordinates}'),
              Text('Distance: ${incident.formattedDistance}'),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('Map View\n(Integration Required)'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openIncidentDetail(incident);
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  void _openIncidentDetail(GeofenceIncident incident) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminIncidentDetailPage(
          incident: incident,
          onIncidentUpdated: () => setState(() {}),
        ),
      ),
    );
  }

  Future<void> _acknowledgeIncident(String incidentId, String studentId) async {
    try {
      await GeofenceIncidentService.acknowledgeIncident(incidentId, 'Admin');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident acknowledged successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error acknowledging incident: $e')),
      );
    }
  }

  Future<void> _resolveIncident(String incidentId, String studentId) async {
    try {
      await GeofenceIncidentService.updateIncident(incidentId, {
        'status': 'resolved',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident resolved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error resolving incident: $e')));
    }
  }

  Future<void> _messageStudent(String studentId, String studentName) async {
    final TextEditingController messageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Message $studentName'),
        content: TextField(
          controller: messageController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter your message here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (messageController.text.trim().isNotEmpty) {
                // TODO: Implement messaging service
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Message sent to $studentName')),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Color _getIncidentStatusColor(GeofenceIncident incident) {
    return _getStatusColor(incident.status);
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        border: Border.all(color: _getStatusColor(status)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  void _showIncidentLocation(GeofenceIncident incident) {
    _showQuickMapView(incident);
  }

  Future<void> _addIncidentNote(GeofenceIncident incident) async {
    final TextEditingController noteController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Note to Incident'),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter administrative note...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (noteController.text.trim().isNotEmpty) {
                try {
                  await GeofenceIncidentService.updateIncident(incident.id, {
                    'adminNotes': FieldValue.arrayUnion([
                      {
                        'note': noteController.text.trim(),
                        'addedBy': 'Admin',
                        'addedAt': FieldValue.serverTimestamp(),
                      },
                    ]),
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Note added successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding note: $e')),
                  );
                }
              }
            },
            child: const Text('Add Note'),
          ),
        ],
      ),
    );
  }

  void _showIncidentStatistics() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading statistics...'),
          ],
        ),
      ),
    );

    try {
      final stats = await GeofenceIncidentService.getIncidentStatistics();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showStatisticsDialog(stats);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading statistics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatisticsDialog(IncidentStatistics stats) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Incident Statistics'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('Total Incidents', stats.totalIncidents.toString()),
              _buildStatRow('Pending', stats.pendingIncidents.toString()),
              _buildStatRow(
                'Acknowledged',
                stats.acknowledgedIncidents.toString(),
              ),
              _buildStatRow('Resolved', stats.resolvedIncidents.toString()),
              const Divider(),
              _buildStatRow('Fixed Band', stats.fixedBandIncidents.toString()),
              _buildStatRow(
                'Floating Band',
                stats.floatingBandIncidents.toString(),
              ),
              if (stats.mostActiveDay != null) ...[
                const Divider(),
                _buildStatRow('Most Active Day', stats.mostActiveDay!),
              ],
              if (stats.studentWithMostIncidents != null) ...[
                _buildStatRow(
                  'Top Student',
                  '${stats.studentWithMostIncidents!.value} incidents',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Filters dialog for incident list
class _FiltersDialog extends StatefulWidget {
  final IncidentFilters currentFilters;
  final Function(IncidentFilters) onFiltersChanged;

  const _FiltersDialog({
    required this.currentFilters,
    required this.onFiltersChanged,
  });

  @override
  State<_FiltersDialog> createState() => _FiltersDialogState();
}

class _FiltersDialogState extends State<_FiltersDialog> {
  late IncidentFilters _filters;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _filters = widget.currentFilters;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Incidents'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range Filter
            const Text(
              'Date Range',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _filters.dateRange != null
                        ? '${_dateFormat.format(_filters.dateRange!.start)} - '
                              '${_dateFormat.format(_filters.dateRange!.end)}'
                        : 'All dates',
                  ),
                ),
                TextButton(
                  onPressed: _selectDateRange,
                  child: Text(_filters.dateRange != null ? 'Change' : 'Select'),
                ),
              ],
            ),
            if (_filters.dateRange != null)
              TextButton(
                onPressed: () => setState(() {
                  _filters = _filters.copyWith(dateRange: null);
                }),
                child: const Text('Clear', style: TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 16),

            // Band Type Filter
            const Text(
              'Band Type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String?>(
              value: _filters.bandType?.isEmpty == true
                  ? null
                  : _filters.bandType,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: null, child: Text('All band types')),
                DropdownMenuItem(value: 'fixed', child: Text('Fixed Band')),
                DropdownMenuItem(
                  value: 'floating',
                  child: Text('Floating Band'),
                ),
              ],
              onChanged: (value) => setState(() {
                _filters = _filters.copyWith(bandType: value);
              }),
            ),

            const SizedBox(height: 16),

            // Status Filter
            const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<String?>(
              value: _filters.status?.isEmpty == true ? null : _filters.status,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: null, child: Text('All statuses')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(
                  value: 'acknowledged',
                  child: Text('Acknowledged'),
                ),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
              ],
              onChanged: (value) => setState(() {
                _filters = _filters.copyWith(status: value);
              }),
            ),

            const SizedBox(height: 16),

            // Direction Filter
            const Text(
              'Direction',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String?>(
              value: _filters.direction?.isEmpty == true
                  ? null
                  : _filters.direction,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: null, child: Text('All directions')),
                DropdownMenuItem(value: 'check_in', child: Text('Check In')),
                DropdownMenuItem(value: 'check_out', child: Text('Check Out')),
              ],
              onChanged: (value) => setState(() {
                _filters = _filters.copyWith(direction: value);
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _filters = const IncidentFilters();
            });
          },
          child: const Text('Clear All'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onFiltersChanged(_filters);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _filters.dateRange,
    );

    if (picked != null) {
      setState(() {
        _filters = _filters.copyWith(dateRange: picked);
      });
    }
  }
}

/// Enhanced admin incident detail page
class AdminIncidentDetailPage extends StatelessWidget {
  final GeofenceIncident incident;
  final VoidCallback? onIncidentUpdated;

  const AdminIncidentDetailPage({
    super.key,
    required this.incident,
    this.onIncidentUpdated,
  });

  Future<void> _acknowledgeIncidentFromDetail(
    BuildContext context,
    GeofenceIncident incident,
  ) async {
    try {
      await GeofenceIncidentService.acknowledgeIncident(incident.id, 'Admin');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident acknowledged successfully')),
        );
        Navigator.pop(context);
        onIncidentUpdated?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error acknowledging incident: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: Text('Incident #${incident.id.substring(0, 8)}'),
        actions: [
          if (incident.status == 'pending')
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: () =>
                  _acknowledgeIncidentFromDetail(context, incident),
              tooltip: 'Mark Acknowledged',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: incident.direction == 'check_in'
                          ? Colors.green
                          : Colors.orange,
                      child: Icon(
                        incident.direction == 'check_in'
                            ? Icons.login
                            : Icons.logout,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${incident.directionDisplay} Incident',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${incident.formattedDistance} outside designated area',
                            style: TextStyle(
                              color: Colors.red[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildBadge(
                                incident.bandType.toUpperCase(),
                                incident.bandType == 'fixed'
                                    ? Colors.red
                                    : Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              _buildBadge(
                                incident.statusDisplay,
                                _getStatusColor(incident.status),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Student Info
            _buildInfoSection('Student Information', [
              _buildInfoRow('Name', incident.studentName),
              _buildInfoRow('ID', incident.studentId),
            ]),

            const SizedBox(height: 16),

            // Timing Info
            _buildInfoSection('Timing Information', [
              _buildInfoRow('Date', dateFormat.format(incident.occurredAt)),
              _buildInfoRow('Time', timeFormat.format(incident.occurredAt)),
              _buildInfoRow(
                'Recorded',
                '${dateFormat.format(incident.createdAt)} at ${timeFormat.format(incident.createdAt)}',
              ),
            ]),

            const SizedBox(height: 16),

            // Location Details
            _buildInfoSection('Location Details', [
              _buildInfoRow('Distance Outside', incident.formattedDistance),
              _buildInfoRow(
                'Designated Location',
                incident.designatedLocation.coordinates,
              ),
              _buildInfoRow(
                'Actual Location',
                incident.actualLocation.coordinates,
              ),
            ]),

            const SizedBox(height: 16),

            // Map Placeholder
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location Map',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map, size: 64, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Map with two pins'),
                            Text('(Designated vs Actual Location)'),
                            Text('Map integration required'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Message Text (if any)
            if (incident.messageText != null &&
                incident.messageText!.isNotEmpty)
              _buildInfoSection('Message Text', [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(incident.messageText!),
                ),
              ]),

            // Acknowledgment Info (if acknowledged)
            if (incident.isAcknowledged) ...[
              const SizedBox(height: 16),
              _buildInfoSection('Acknowledgment Details', [
                _buildInfoRow('Status', incident.statusDisplay),
                if (incident.acknowledgedBy != null)
                  _buildInfoRow('Acknowledged By', incident.acknowledgedBy!),
                if (incident.acknowledgedAt != null)
                  _buildInfoRow(
                    'Acknowledged At',
                    '${dateFormat.format(incident.acknowledgedAt!)} at ${timeFormat.format(incident.acknowledgedAt!)}',
                  ),
                if (incident.notes != null && incident.notes!.isNotEmpty)
                  _buildInfoRow('Notes', incident.notes!),
              ]),
            ],

            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: incident.status == 'pending'
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _acknowledgeIncidentFromDetail(context, incident),
              icon: const Icon(Icons.check),
              label: const Text('Mark Acknowledged'),
            )
          : null,
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'acknowledged':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
