import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class EnhancedAdminIncidentPage extends StatefulWidget {
  const EnhancedAdminIncidentPage({super.key});

  @override
  State<EnhancedAdminIncidentPage> createState() =>
      _EnhancedAdminIncidentPageState();
}

class _EnhancedAdminIncidentPageState extends State<EnhancedAdminIncidentPage> {
  String? selectedUserId;
  List<Map<String, dynamic>> allUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
  }

  Future<void> _loadAllUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('lastName')
          .get();

      setState(() {
        allUsers = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
            'email': data['email'] ?? '',
            'role': data['role'] ?? 'student',
          };
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F9FC),
      
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('geofence_incidents')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading incidents...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading incidents: ${snapshot.error}'),
            );
          }

          final incidents = snapshot.data?.docs ?? [];

          // Group incidents by student
          final Map<String, List<QueryDocumentSnapshot>> incidentsByStudent =
              {};
          final Set<String> studentsWithIncidents = {};

          for (final incident in incidents) {
            final userId = incident['userId'] as String?;
            if (userId != null) {
              studentsWithIncidents.add(userId);
              if (!incidentsByStudent.containsKey(userId)) {
                incidentsByStudent[userId] = [];
              }
              incidentsByStudent[userId]!.add(incident);
            }
          }

          return Column(
            children: [
              // Header with Stats
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    

                    // Quick Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Students with Incidents',
                            studentsWithIncidents.length.toString(),
                            Icons.people_outline,
                            Colors.red,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Total Incidents',
                            incidents.length.toString(),
                            Icons.report_problem,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Student Selection Filter
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text('Filter by student (optional)'),
                          value: selectedUserId,
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Students'),
                            ),
                            ...allUsers
                                .where(
                                  (user) => studentsWithIncidents.contains(
                                    user['id'],
                                  ),
                                )
                                .map((user) {
                                  final count =
                                      incidentsByStudent[user['id']]?.length ??
                                      0;
                                  return DropdownMenuItem<String>(
                                    value: user['id'],
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text('${user['name']}'),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red[100],
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '$count',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedUserId = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Incidents List
              Expanded(
                child: _buildIncidentsList(incidents, incidentsByStudent),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentsList(
    List<QueryDocumentSnapshot> incidents,
    Map<String, List<QueryDocumentSnapshot>> incidentsByStudent,
  ) {
    List<QueryDocumentSnapshot> filteredIncidents;

    if (selectedUserId == null) {
      filteredIncidents = incidents;
    } else {
      filteredIncidents = incidentsByStudent[selectedUserId] ?? [];
    }

    if (filteredIncidents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              selectedUserId == null
                  ? 'No incidents recorded'
                  : 'No incidents for this student',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredIncidents.length,
      itemBuilder: (context, index) {
        final incident = filteredIncidents[index];
        return _buildIncidentCard(incident.data() as Map<String, dynamic>);
      },
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    final userName = incident['userName'] ?? 'Unknown Student';
    final timestamp = incident['timestamp'] as Timestamp?;
    final actualLat = incident['actualLatitude'];
    final actualLng = incident['actualLongitude'];
    final expectedLat = incident['expectedLatitude'];
    final expectedLng = incident['expectedLongitude'];

    // Calculate distance
    double distance = 0;
    if (actualLat != null &&
        actualLng != null &&
        expectedLat != null &&
        expectedLng != null) {
      distance = _calculateDistance(
        actualLat,
        actualLng,
        expectedLat,
        expectedLng,
      );
    }

    final timeString = timestamp != null
        ? DateFormat('MMM dd, yyyy • HH:mm').format(timestamp.toDate())
        : 'Unknown time';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showIncidentDetails(incident),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_off,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          timeString,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${distance.toStringAsFixed(0)}m',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: distance > 100 ? Colors.red : Colors.orange,
                        ),
                      ),
                      Text(
                        'distance',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Student was outside designated geofence area',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371000; // meters

    double dLat = (lat2 - lat1) * (math.pi / 180);
    double dLng = (lng2 - lng1) * (math.pi / 180);

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  void _showIncidentDetails(Map<String, dynamic> incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Incident Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Divider(height: 1),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIncidentDetailItem(
                      'Student',
                      incident['userName'] ?? 'Unknown',
                    ),
                    _buildIncidentDetailItem(
                      'Date & Time',
                      incident['timestamp'] != null
                          ? DateFormat('EEEE, MMMM dd, yyyy • HH:mm:ss').format(
                              (incident['timestamp'] as Timestamp).toDate(),
                            )
                          : 'Unknown',
                    ),
                    _buildIncidentDetailItem(
                      'Actual Location',
                      '${incident['actualLatitude']?.toStringAsFixed(6) ?? 'N/A'}, ${incident['actualLongitude']?.toStringAsFixed(6) ?? 'N/A'}',
                    ),
                    _buildIncidentDetailItem(
                      'Expected Location',
                      '${incident['expectedLatitude']?.toStringAsFixed(6) ?? 'N/A'}, ${incident['expectedLongitude']?.toStringAsFixed(6) ?? 'N/A'}',
                    ),
                    _buildIncidentDetailItem(
                      'Distance from Expected',
                      '${_calculateDistance(incident['actualLatitude'] ?? 0, incident['actualLongitude'] ?? 0, incident['expectedLatitude'] ?? 0, incident['expectedLongitude'] ?? 0).toStringAsFixed(2)} meters',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50))),
        ],
      ),
    );
  }
}
