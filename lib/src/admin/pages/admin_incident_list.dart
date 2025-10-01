import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/admin/pages/admin_incident_detail_page.dart';


class AdminIncidentsList extends StatefulWidget {
  final String studentId;

  const AdminIncidentsList({super.key, required this.studentId});

  @override
  State<AdminIncidentsList> createState() => _AdminIncidentsListState();
}

class _AdminIncidentsListState extends State<AdminIncidentsList> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Geofence Incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by Date Range',
            onPressed: _pickDateRange,
          ),
          if (_startDate != null && _endDate != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Filter',
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _incidentStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No incidents logged.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final type = (data['type'] ?? '').toString();
              final dateId = (data['dateId'] ?? '').toString();
              final distance = (data['distance'] ?? 0).toDouble();
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              return ListTile(
                leading: Icon(
                  type == 'checkin' ? Icons.login : Icons.logout,
                  color: type == 'checkin' ? Colors.green : Colors.red,
                ),
                title: Text(
                  '${type.toUpperCase()} • ${distance.toStringAsFixed(1)} m outside zone',
                ),
                subtitle: Text(
                  createdAt != null
                      ? 'Date: $dateId  •  Logged: ${createdAt.toLocal()}'
                      : 'Date: $dateId',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminIncidentDetailPage(data: data),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _incidentStream() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('geofenceIncidents')
        .doc(widget.studentId)
        .collection('incidents');

    if (_startDate != null && _endDate != null) {
      query = query
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate!));
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        // include the end date by adding a day at midnight
        _endDate = picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      });
    }
  }
}
