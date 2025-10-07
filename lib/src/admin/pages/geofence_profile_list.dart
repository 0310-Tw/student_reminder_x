import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/admin/pages/admin_geofence_editor.dart';

class GeofenceProfilesList extends StatelessWidget {
  final String studentId;

  const GeofenceProfilesList({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geofence Profiles')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .collection('geofence_profiles')
            .orderBy(FieldPath.documentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No profiles saved.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final dateId = doc.id;
              final bandType = data['bandType'] ?? 'fixed';
              final outsidePolicy = data['outsidePolicy'] ?? 'block';
              final checkIn = data['checkInLocation'] as Map<String, dynamic>;
              final checkOut = data['checkOutLocation'] as Map<String, dynamic>;

              return ListTile(
                title: Text('Date: $dateId'),
                subtitle: Text(
                  'Band: $bandType  •  Policy: $outsidePolicy\n'
                  'In: (${checkIn['lat']},${checkIn['lng']}, r=${checkIn['radius']}m)\n'
                  'Out: (${checkOut['lat']},${checkOut['lng']}, r=${checkOut['radius']}m)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminGeofenceEditor(
                        studentId: studentId,
                        dateId: dateId,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newDateId = await _promptForDateId(context);
          if (newDateId != null && newDateId.isNotEmpty) {
            // Open the editor with a fresh dateId
            // ignore: use_build_context_synchronously
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminGeofenceEditor(
                  studentId: studentId,
                  dateId: newDateId,
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Profile'),
      ),
    );
  }

  Future<String?> _promptForDateId(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Profile Date'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter dateId (YYYYMMDD), e.g. 20251001',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}