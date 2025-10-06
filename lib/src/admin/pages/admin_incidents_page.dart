import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
                        Icon(Icons.check_circle, 
                            size: 64, color: Colors.green[300]),
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
          if (_filters.studentClass != null && _filters.studentClass!.isNotEmpty)
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
              label: Text('Direction: ${_filters.direction?.replaceAll('_', ' ')}'),
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: incident.direction == 'check_in' 
              ? Colors.green : Colors.orange,
          child: Icon(
            incident.direction == 'check_in' ? Icons.login : Icons.logout,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          '${incident.studentName} (${incident.studentId})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${incident.directionDisplay} • ${incident.formattedDistance} outside',
              style: TextStyle(
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_dateFormat.format(incident.occurredAt)} at ${_timeFormat.format(incident.occurredAt)}',
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: incident.bandType == 'fixed' 
                        ? Colors.red[100] : Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    incident.bandType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: incident.bandType == 'fixed' 
                          ? Colors.red[800] : Colors.blue[800],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(incident.status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    incident.statusDisplay,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
            IconButton(
              icon: const Icon(Icons.map, color: Colors.blue),
              onPressed: () => _showQuickMapView(incident),
              tooltip: 'Quick Map View',
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _openIncidentDetail(incident),
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
              _buildStatRow('Acknowledged', stats.acknowledgedIncidents.toString()),
              _buildStatRow('Resolved', stats.resolvedIncidents.toString()),
              const Divider(),
              _buildStatRow('Fixed Band', stats.fixedBandIncidents.toString()),
              _buildStatRow('Floating Band', stats.floatingBandIncidents.toString()),
              if (stats.mostActiveDay != null) ...[
                const Divider(),
                _buildStatRow('Most Active Day', stats.mostActiveDay!),
              ],
              if (stats.studentWithMostIncidents != null) ...[
                _buildStatRow('Top Student', 
                  '${stats.studentWithMostIncidents!.value} incidents'),
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
            const Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('Band Type', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<String?>(
              value: _filters.bandType?.isEmpty == true ? null : _filters.bandType,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: null, child: Text('All band types')),
                DropdownMenuItem(value: 'fixed', child: Text('Fixed Band')),
                DropdownMenuItem(value: 'floating', child: Text('Floating Band')),
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
                DropdownMenuItem(value: 'acknowledged', child: Text('Acknowledged')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
              ],
              onChanged: (value) => setState(() {
                _filters = _filters.copyWith(status: value);
              }),
            ),

            const SizedBox(height: 16),

            // Direction Filter
            const Text('Direction', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<String?>(
              value: _filters.direction?.isEmpty == true ? null : _filters.direction,
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: Text('Incident #${incident.id.substring(0, 8)}'),
        actions: [
          if (!incident.isAcknowledged)
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: () => _acknowledgeIncident(context),
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
                          ? Colors.green : Colors.orange,
                      child: Icon(
                        incident.direction == 'check_in' ? Icons.login : Icons.logout,
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
                              _buildBadge(incident.bandType.toUpperCase(), 
                                  incident.bandType == 'fixed' ? Colors.red : Colors.blue),
                              const SizedBox(width: 8),
                              _buildBadge(incident.statusDisplay, 
                                  _getStatusColor(incident.status)),
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
            _buildInfoSection(
              'Student Information',
              [
                _buildInfoRow('Name', incident.studentName),
                _buildInfoRow('ID', incident.studentId),
              ],
            ),

            const SizedBox(height: 16),

            // Timing Info
            _buildInfoSection(
              'Timing Information',
              [
                _buildInfoRow('Date', dateFormat.format(incident.occurredAt)),
                _buildInfoRow('Time', timeFormat.format(incident.occurredAt)),
                _buildInfoRow('Recorded', 
                    '${dateFormat.format(incident.createdAt)} at ${timeFormat.format(incident.createdAt)}'),
              ],
            ),

            const SizedBox(height: 16),

            // Location Details
            _buildInfoSection(
              'Location Details',
              [
                _buildInfoRow('Distance Outside', incident.formattedDistance),
                _buildInfoRow('Designated Location', incident.designatedLocation.coordinates),
                _buildInfoRow('Actual Location', incident.actualLocation.coordinates),
              ],
            ),

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
            if (incident.messageText != null && incident.messageText!.isNotEmpty)
              _buildInfoSection(
                'Message Text',
                [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(incident.messageText!),
                  ),
                ],
              ),

            // Acknowledgment Info (if acknowledged)
            if (incident.isAcknowledged) ...[
              const SizedBox(height: 16),
              _buildInfoSection(
                'Acknowledgment Details',
                [
                  _buildInfoRow('Status', incident.statusDisplay),
                  if (incident.acknowledgedBy != null)
                    _buildInfoRow('Acknowledged By', incident.acknowledgedBy!),
                  if (incident.acknowledgedAt != null)
                    _buildInfoRow('Acknowledged At', 
                        '${dateFormat.format(incident.acknowledgedAt!)} at ${timeFormat.format(incident.acknowledgedAt!)}'),
                  if (incident.notes != null && incident.notes!.isNotEmpty)
                    _buildInfoRow('Notes', incident.notes!),
                ],
              ),
            ],

            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: incident.isAcknowledged 
          ? null 
          : FloatingActionButton.extended(
              onPressed: () => _acknowledgeIncident(context),
              icon: const Icon(Icons.check),
              label: const Text('Mark Acknowledged'),
            ),
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
          Expanded(
            child: Text(value),
          ),
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

  void _acknowledgeIncident(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AcknowledgeIncidentDialog(
        incident: incident,
        onAcknowledged: () {
          if (context.mounted) {
            Navigator.pop(context); // Close detail page
            onIncidentUpdated?.call();
          }
        },
      ),
    );
  }
}

/// Dialog for acknowledging incidents
class _AcknowledgeIncidentDialog extends StatefulWidget {
  final GeofenceIncident incident;
  final VoidCallback? onAcknowledged;

  const _AcknowledgeIncidentDialog({
    required this.incident,
    this.onAcknowledged,
  });

  @override
  State<_AcknowledgeIncidentDialog> createState() => _AcknowledgeIncidentDialogState();
}

class _AcknowledgeIncidentDialogState extends State<_AcknowledgeIncidentDialog> {
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Acknowledge Incident'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mark this incident as acknowledged for ${widget.incident.studentName}?',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Add any additional notes...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _acknowledgeIncident,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Acknowledge'),
        ),
      ],
    );
  }

  void _acknowledgeIncident() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Get current admin user ID - for now using placeholder
      const adminId = 'current_admin_id';
      
      await GeofenceIncidentService.acknowledgeIncident(
        widget.incident.id,
        adminId,
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        widget.onAcknowledged?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident acknowledged successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error acknowledging incident: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}