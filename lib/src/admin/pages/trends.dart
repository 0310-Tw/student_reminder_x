import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:students_reminder/src/admin/pages/enhanced_admin_geofence_page.dart';
import 'package:students_reminder/src/admin/pages/enhanced_admin_incident_page.dart';

class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key});

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Safety check: if widget is disposed, return empty container
    if (_disposed || !mounted) {
      return Scaffold(
        backgroundColor: Color(0xFFF7F9FC),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: Color(0xFF2C3E50),
          foregroundColor: Colors.white,
          title: Text('Admin Dashboard'),
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            tabs: [
              Tab(icon: Icon(Icons.trending_up), text: 'Trends'),
              Tab(icon: Icon(Icons.location_on), text: 'Geofence'),
              Tab(icon: Icon(Icons.report_problem), text: 'Incidents'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Trends Tab
            _buildTrendsTab(),

            // Geofence Editor Tab
            _buildGeofenceTab(),

            // Incident Details Tab
            EnhancedAdminIncidentPage(),
            
          ],
        ),
      ),
    );
  }

  // Trends Tab Content
  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekly Trend Comparison
          _buildWeeklyTrendComparison(),
          SizedBox(height: 20),

          // Frequently Late Students
          _buildFrequentlyLateStudents(),
        ],
      ),
    );
  }

  // Geofence Tab Content
  Widget _buildGeofenceTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Overview Statistics Grid
          _buildOverviewStats(),

          SizedBox(height: 16),

         

          SizedBox(height: 24),

          // Divider and Enhanced Management Section
          Divider(color: Colors.grey[300]),
          SizedBox(height: 16),

          Text(
            'Advanced Management',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 16),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF9B59B6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            ),
            icon: Icon(Icons.admin_panel_settings, color: Colors.white),
            label: Text(
              'Tap to Edit and View',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EnhancedAdminGeofencePage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Incidents Tab Content
 
  

  // Weekly Trend Comparison Widget
  Widget _buildWeeklyTrendComparison() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getAllAttendanceStream(),
      builder: (context, snapshot) {
        // Check if widget is disposed to prevent rebuilds during disposal
        if (_disposed || !mounted) {
          return SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildTrendLoading();
        }

        if (snapshot.hasError) {
          print('StreamBuilder error in trends: ${snapshot.error}');
          return _buildTrendError('Error loading trend data');
        }

        final attendanceRecords = snapshot.data?.docs ?? [];
        final trendData = _calculateWeeklyTrend(attendanceRecords);

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, color: Color(0xFF3498DB), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Weekly Trend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This Week',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${trendData['thisWeek']} lates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'vs Last Week',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            trendData['trendIcon'],
                            color: trendData['trendColor'],
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            trendData['trendText'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: trendData['trendColor'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: trendData['progressValue'],
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3498DB)),
              ),
              SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Last Week: ${trendData['lastWeek']} lates',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '${(trendData['progressValue'] * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Frequently Late Students Widget
  Widget _buildFrequentlyLateStudents() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getAllAttendanceStream(),
      builder: (context, snapshot) {
        // Check if widget is disposed to prevent rebuilds during disposal
        if (_disposed || !mounted) {
          return SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildFrequentlyLateLoading();
        }

        if (snapshot.hasError) {
          print('StreamBuilder error in late students: ${snapshot.error}');
          return _buildFrequentlyLateError('Error loading late students');
        }

        final attendanceRecords = snapshot.data?.docs ?? [];

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getFrequentlyLateStudents(attendanceRecords),
          builder: (context, futureSnapshot) {
            // Check if widget is disposed to prevent rebuilds during disposal
            if (_disposed || !mounted) {
              return SizedBox.shrink();
            }

            if (futureSnapshot.connectionState == ConnectionState.waiting) {
              return _buildFrequentlyLateLoading();
            }

            if (futureSnapshot.hasError) {
              print(
                'FutureBuilder error in student names: ${futureSnapshot.error}',
              );
              return _buildFrequentlyLateError('Error loading student names');
            }

            final frequentlyLateStudents = futureSnapshot.data ?? [];

            return Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFFF9800).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Color(0xFFFF9800),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Frequently Late (2 or more times)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  if (frequentlyLateStudents.isEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.celebration,
                              color: Colors.green,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No frequently late students!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: frequentlyLateStudents.take(10).map((student) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Color(
                                  0xFFFF9800,
                                ).withOpacity(0.2),
                                radius: 20,
                                child: Text(
                                  student['name'].isNotEmpty
                                      ? student['name'][0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: Color(0xFFFF9800),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '${student['lateCount']} late arrivals',
                                      style: TextStyle(
                                        color: Color(0xFFFF9800),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFF9800).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${student['lateCount']}×',
                                  style: TextStyle(
                                    color: Color(0xFFFF9800),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  if (frequentlyLateStudents.length > 10)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '+ ${frequentlyLateStudents.length - 10} more students',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper methods (copied from admin dashboard)
  Stream<QuerySnapshot> _getAllAttendanceStream() {
    return FirebaseFirestore.instance.collectionGroup('days').snapshots();
  }

  String _formatDateId(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<String, dynamic> _calculateWeeklyTrend(
    List<DocumentSnapshot> allRecords,
  ) {
    final now = DateTime.now();

    // This week (Monday to Sunday)
    final weekday = now.weekday;
    final startOfThisWeek = now.subtract(Duration(days: weekday - 1));
    final endOfThisWeek = startOfThisWeek.add(Duration(days: 6));

    // Last week (previous Monday to Sunday)
    final startOfLastWeek = startOfThisWeek.subtract(Duration(days: 7));
    final endOfLastWeek = endOfThisWeek.subtract(Duration(days: 7));

    final thisWeekStartId = _formatDateId(startOfThisWeek);
    final thisWeekEndId = _formatDateId(endOfThisWeek);
    final lastWeekStartId = _formatDateId(startOfLastWeek);
    final lastWeekEndId = _formatDateId(endOfLastWeek);

    int thisWeekLates = 0;
    int lastWeekLates = 0;

    for (final record in allRecords) {
      final data = record.data() as Map<String, dynamic>;
      final dayId = data['dayId'] as String? ?? '';
      final status = data['status'] as String? ?? 'absent';

      if (status == 'late' || data['lateReason'] != null) {
        if (dayId.compareTo(thisWeekStartId) >= 0 &&
            dayId.compareTo(thisWeekEndId) <= 0) {
          thisWeekLates++;
        } else if (dayId.compareTo(lastWeekStartId) >= 0 &&
            dayId.compareTo(lastWeekEndId) <= 0) {
          lastWeekLates++;
        }
      }
    }

    // Calculate trend
    double percentageChange = 0.0;
    if (lastWeekLates > 0) {
      percentageChange =
          ((thisWeekLates - lastWeekLates) / lastWeekLates) * 100;
    } else if (thisWeekLates > 0) {
      percentageChange = 100.0; // No lates last week, but lates this week
    }

    IconData trendIcon;
    Color trendColor;
    String trendText;

    if (percentageChange > 0) {
      trendIcon = Icons.arrow_upward;
      trendColor = Colors.red;
      trendText = '+${percentageChange.toStringAsFixed(1)}%';
    } else if (percentageChange < 0) {
      trendIcon = Icons.arrow_downward;
      trendColor = Colors.green;
      trendText = '${percentageChange.toStringAsFixed(1)}%';
    } else {
      trendIcon = Icons.remove;
      trendColor = Colors.grey;
      trendText = '0%';
    }

    // Calculate progress value for visualization
    double progressValue = 0.0;
    if (thisWeekLates > 0 || lastWeekLates > 0) {
      final maxLates = thisWeekLates > lastWeekLates
          ? thisWeekLates
          : lastWeekLates;
      progressValue = thisWeekLates / (maxLates == 0 ? 1 : maxLates);
    }

    return {
      'thisWeek': thisWeekLates,
      'lastWeek': lastWeekLates,
      'trendIcon': trendIcon,
      'trendColor': trendColor,
      'trendText': trendText,
      'progressValue': progressValue,
    };
  }

  Future<List<Map<String, dynamic>>> _getFrequentlyLateStudents(
    List<DocumentSnapshot> allRecords,
  ) async {
    final studentLateCounts = <String, int>{};
    final studentNames = <String, String>{};

    // Count late occurrences per student
    for (final record in allRecords) {
      final data = record.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'absent';

      if (status == 'late' || data['lateReason'] != null) {
        final userId = record.reference.parent.parent?.id ?? '';
        if (userId.isNotEmpty) {
          studentLateCounts[userId] = (studentLateCounts[userId] ?? 0) + 1;

          // Fetch student name if not already stored
          if (!studentNames.containsKey(userId)) {
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                final firstName = userData['firstName'] ?? '';
                final lastName = userData['lastName'] ?? '';
                studentNames[userId] = '$firstName $lastName'.trim();
              } else {
                studentNames[userId] = 'Unknown Student';
              }
            } catch (e) {
              studentNames[userId] = 'Unknown Student';
            }
          }
        }
      }
    }

    // Convert to list and filter students with ≥2 lates
    final frequentlyLate = studentLateCounts.entries
        .where((entry) => entry.value >= 2)
        .map(
          (entry) => {
            'id': entry.key,
            'name': studentNames[entry.key] ?? 'Unknown Student',
            'lateCount': entry.value,
          },
        )
        .toList();

    // Sort by late count (descending)
    frequentlyLate.sort(
      (a, b) => ((b['lateCount'] ?? 0) as int).compareTo(
        (a['lateCount'] ?? 0) as int,
      ),
    );
    return frequentlyLate;
  }

  Widget _buildTrendLoading() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.withOpacity(0.2),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 12,
                  color: Colors.grey.withOpacity(0.2),
                ),
                SizedBox(height: 8),
                Container(
                  width: 150,
                  height: 10,
                  color: Colors.grey.withOpacity(0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendError(String message) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequentlyLateLoading() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFFF9800).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.withOpacity(0.2),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 14,
                  color: Colors.grey.withOpacity(0.2),
                ),
                SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 10,
                  color: Colors.grey.withOpacity(0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequentlyLateError(String message) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnapshot) {
        if (usersSnapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (usersSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Error loading data: ${usersSnapshot.error}'),
            ),
          );
        }

        // Calculate real statistics from user data
        int totalStudents = 0;
        int usersWithGeofences = 0;
        int totalCustomLocations = 0;

        if (usersSnapshot.hasData) {
          for (var doc in usersSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>?;

            if (data != null) {
              // Count all users as students (exclude admin check for now)
              totalStudents++;

              // Check if user has geofences configured
              if (data['geofences'] != null) {
                usersWithGeofences++;

                final geofences = data['geofences'] as Map<String, dynamic>;
                totalCustomLocations += geofences.length;
              }
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('geofence_incidents')
              .snapshots(),
          builder: (context, incidentsSnapshot) {
            // Count recent incidents/overrides (last 30 days)
            int recentIncidents = 0;

            if (incidentsSnapshot.hasData) {
              final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));

              for (var doc in incidentsSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>?;
                if (data?['timestamp'] != null) {
                  try {
                    final timestamp = (data!['timestamp'] as Timestamp)
                        .toDate();
                    if (timestamp.isAfter(thirtyDaysAgo)) {
                      recentIncidents++;
                    }
                  } catch (e) {
                    // Handle timestamp parsing errors gracefully
                  }
                }
              }
            }

            return GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Total Students',
                  totalStudents.toString(),
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Users with Geofences',
                  usersWithGeofences.toString(),
                  Icons.location_on,
                  Colors.green,
                ),
                _buildStatCard(
                  'Custom Locations',
                  totalCustomLocations.toString(),
                  Icons.place,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Recent Incidents',
                  recentIncidents.toString(),
                  Icons.warning,
                  Colors.purple,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              Spacer(),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Create Profile',
                Icons.add_location,
                Colors.green,
                () {
                  // Navigate to create profile
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Bulk Override',
                Icons.edit_location,
                Colors.orange,
                () {
                  // Navigate to bulk override
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
