import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/admin/incidents/incident_detail_page.dart';

class IncidentsPage extends StatelessWidget {
  final String studentId; // pass in the current student's UID

  const IncidentsPage({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geofence Incidents')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('geofenceIncidents')
            .doc(studentId)
            .collection('incidents')
            .orderBy('createdAt', descending: true)
            .snapshots(),
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
                      builder: (_) => IncidentDetailPage(data: data),
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
}
