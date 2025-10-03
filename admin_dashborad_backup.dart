import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:students_reminder/src/admin/pages/trends.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _selectedPeriod = 'Today';
  List<String> _periods = ['Today', 'This Week', 'This Month'];
  String _studentFilter = 'All'; // 'All', 'Web', 'Mobile'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        title: Text('Admin Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.person_add, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/admin-profileview-page');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Fixed header section
          Container(
            color: Color(0xFFF7F9FC),
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period Selector
                _buildPeriodSelector(),
                SizedBox(height: 20),

                // Today's Quick Stats (fixed at top)
                if (_selectedPeriod == 'Today') ...[
                  _buildTodayStats(),
                  SizedBox(height: 20),
                ],
              ],
            ),
          ),

          // Scrollable content section
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attendance Overview
                  _buildAttendanceOverview(),
                  SizedBox(height: 20),

                  // Student List
                  _buildStudentAttendanceList(),
                  SizedBox(height: 16), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: _periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Color(0xFF3498DB) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Color(0xFF6C7B7F),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTodayStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getTodayAttendanceStream(),
      builder: (context, attendanceSnapshot) {
        if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
          return _buildStatsLoading();
        }

        if (attendanceSnapshot.hasError) {
          print('Attendance stream error: ${attendanceSnapshot.error}');
          return _buildStatsError(
            'Error loading attendance: ${attendanceSnapshot.error}',
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _getStudentsStream(),
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.connectionState == ConnectionState.waiting) {
              return _buildStatsLoading();
            }

            if (studentsSnapshot.hasError) {
              print('Students stream error: ${studentsSnapshot.error}');
              return _buildStatsError(
                'Error loading students: ${studentsSnapshot.error}',
              );
            }

            if (!studentsSnapshot.hasData ||
                studentsSnapshot.data!.docs.isEmpty) {
              return _buildStatsError('No students found in database');
            }

            final attendanceRecords = attendanceSnapshot.data?.docs ?? [];
            final totalStudents = studentsSnapshot.data!.docs.length;
            final stats = _calculateTodayStats(
              attendanceRecords,
              totalStudents,
            );

            print('Total students: $totalStudents');
            print('Attendance records: ${attendanceRecords.length}');
            print('Today date ID: ${_formatDateId(DateTime.now())}');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Late Arrivals',
                        stats['late'].toString(),
                        Icons.schedule,
                        Color(0xFFFF9800),
                        () => _showLateStudentsList(attendanceRecords),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Early Departures',
                        stats['early'].toString(),
                        Icons.logout,
                        Color(0xFFE74C3C),
                        () => _showEarlyStudentsList(attendanceRecords),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Present',
                        stats['present'].toString(),
                        Icons.check_circle,
                        Color(0xFF27AE60),
                        () => _showPresentStudentsList(attendanceRecords),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Absent',
                        stats['absent'].toString(),
                        Icons.cancel,
                        Color(0xFF95A5A6),
                        () => _showAbsentStudentsBottomSheet(),
                      ),
                    ),
                  ],
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
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildLoadingCard()),
            SizedBox(width: 12),
            Expanded(child: _buildLoadingCard()),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildLoadingCard()),
            SizedBox(width: 12),
            Expanded(child: _buildLoadingCard()),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3498DB),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildStatsError(String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(message, style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceOverview() {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // If swipe is to the left, navigate to trends page
        if (details.velocity.pixelsPerSecond.dx < -500) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TrendsPage()),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8FAFB)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(0xFF3498DB).withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF3498DB).withOpacity(0.25),
              blurRadius: 25,
              offset: Offset(0, 10),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 15,
              offset: Offset(0, 5),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Colors.white,
              blurRadius: 8,
              offset: Offset(0, -2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_selectedPeriod Attendance Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E50),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: _getAttendanceStream(),
              builder: (context, attendanceSnapshot) {
                if (attendanceSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (attendanceSnapshot.hasError) {
                  print(
                    'Attendance overview error: ${attendanceSnapshot.error}',
                  );
                  print(
                    'Error details: ${attendanceSnapshot.error.runtimeType}',
                  );
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Error loading attendance data',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${attendanceSnapshot.error}',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _getStudentsStream(),
                  builder: (context, studentsSnapshot) {
                    if (studentsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (studentsSnapshot.hasError) {
                      print(
                        'Students overview error: ${studentsSnapshot.error}',
                      );
                      return Center(
                        child: Text(
                          'Error loading student data',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (!studentsSnapshot.hasData ||
                        studentsSnapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No students found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final totalStudents = studentsSnapshot.data!.docs.length;
                    final attendanceRecords =
                        attendanceSnapshot.data?.docs ?? [];
                    final stats = _calculateAttendanceStats(
                      attendanceRecords,
                      totalStudents,
                    );

                    print(
                      'Overview - Total students: $totalStudents, Records: ${attendanceRecords.length}',
                    );

                    return Column(
                      children: [
                        _buildProgressIndicator(
                          'Present',
                          stats['present'] ?? 0,
                          stats['total'] ?? 0,
                          Color(0xFF27AE60),
                        ),
                        SizedBox(height: 12),
                        _buildProgressIndicator(
                          'Absent',
                          stats['absent'] ?? 0,
                          stats['total'] ?? 0,
                          Color(0xFFE74C3C),
                        ),
                        SizedBox(height: 12),
                        _buildProgressIndicator(
                          'Late',
                          stats['late'] ?? 0,
                          stats['total'] ?? 0,
                          Color(0xFFFF9800),
                        ),
                        SizedBox(height: 12),
                        // Only show At Risk section for weekly and monthly views
                        if (_selectedPeriod == 'This Week' ||
                            _selectedPeriod == 'This Month')
                          _buildAtRiskProgressIndicator(attendanceRecords),
                        if (_selectedPeriod == 'This Week' ||
                            _selectedPeriod == 'This Month')
                          SizedBox(height: 12),
                        SizedBox(height: 20),
                        // Enhanced swipe indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF3498DB),
                                    Color(0xFF2980B9),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF3498DB).withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 12),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(0xFF3498DB).withOpacity(0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(
    String label,
    int value,
    int total,
    Color color, {
    VoidCallback? onTap,
  }) {
    final percentage = total > 0 ? (value / total) : 0.0;

    Widget container = Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$value',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${(percentage * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage.clamp(0.0, 1.0), // Cap at 100%
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return onTap != null
        ? GestureDetector(onTap: onTap, child: container)
        : container;
  }

  Widget _buildAtRiskProgressIndicator(
    List<QueryDocumentSnapshot> attendanceRecords,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collectionGroup('at-risk').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (snapshot.hasError) {
          print('At Risk StreamBuilder error: ${snapshot.error}');
          return Container(); // Return empty on error
        }

        if (!snapshot.hasData) {
          return Container(); // Return empty container while loading
        }

        final atRiskDocs = snapshot.data!.docs;
        final Map<String, Map<String, dynamic>> uniqueAtRiskStudents = {};

        // Process at-risk documents and ensure unique students
        for (final doc in atRiskDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final studentId = doc.reference.parent.parent?.id;

          // Get absence counts and risk flags
          final weeklyAbsences = data['weeklyAbsences'] ?? 0;
          final monthlyAbsences = data['monthlyAbsences'] ?? 0;
          final weeklyRisk = data['riskFactors']?['weeklyRisk'] ?? false;
          final monthlyRisk = data['riskFactors']?['monthlyRisk'] ?? false;

          // Apply At Risk criteria - student must meet at least one condition:
          // 1. Weekly Risk: 2+ absences in a week OR weeklyRisk flag is true
          // 2. Monthly Risk: 8+ absences in a month OR monthlyRisk flag is true
          final meetsWeeklyRisk = weeklyAbsences >= 2 || weeklyRisk;
          final meetsMonthlyRisk = monthlyAbsences >= 8 || monthlyRisk;
          final isActuallyAtRisk = meetsWeeklyRisk || meetsMonthlyRisk;

          if (isActuallyAtRisk && studentId != null) {
            // Only add if not already present, or if this document is more recent
            final lastUpdated = data['lastUpdated'] as Timestamp?;

            if (!uniqueAtRiskStudents.containsKey(studentId)) {
              uniqueAtRiskStudents[studentId] = {
                'id': studentId,
                'data': data,
                'weeklyAbsences': weeklyAbsences,
                'monthlyAbsences': monthlyAbsences,
                'weeklyRisk': weeklyRisk,
                'monthlyRisk': monthlyRisk,
                'meetsWeeklyRisk': meetsWeeklyRisk,
                'meetsMonthlyRisk': meetsMonthlyRisk,
                'lastUpdated': data['lastUpdated'],
              };
            } else {
              // If student already exists, keep the more recent record
              final existingLastUpdated =
                  uniqueAtRiskStudents[studentId]!['lastUpdated'] as Timestamp?;
              if (lastUpdated != null &&
                  (existingLastUpdated == null ||
                      lastUpdated.compareTo(existingLastUpdated) > 0)) {
                uniqueAtRiskStudents[studentId] = {
                  'id': studentId,
                  'data': data,
                  'weeklyAbsences': weeklyAbsences,
                  'monthlyAbsences': monthlyAbsences,
                  'weeklyRisk': weeklyRisk,
                  'monthlyRisk': monthlyRisk,
                  'meetsWeeklyRisk': meetsWeeklyRisk,
                  'meetsMonthlyRisk': meetsMonthlyRisk,
                  'lastUpdated': data['lastUpdated'],
                };
              }
            }
          }
        }

        final atRiskStudents = uniqueAtRiskStudents.values.toList();

        // Get total student count from a separate stream
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .snapshots(),
          builder: (context, studentSnapshot) {
            if (!studentSnapshot.hasData) {
              return Container();
            }

            final totalStudents = studentSnapshot.data!.docs.length;
            final atRiskCount = atRiskStudents.length;
            final percentage = totalStudents > 0
                ? (atRiskCount / totalStudents)
                : 0.0;
            final color = Color(0xFF9B59B6); // Purple color for At Risk

            return GestureDetector(
              onTap: () => _showAtRiskStudentsBottomSheet(atRiskStudents),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$atRiskCount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'At Risk',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${(percentage * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: percentage.clamp(
                                0.0,
                                1.0,
                              ), // Cap at 100%
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [color, color.withOpacity(0.8)],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.4),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterButton(String filter) {
    final isSelected = _studentFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _studentFilter = filter;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF3498DB) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Color(0xFF3498DB) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filter == 'All'
                  ? Icons.people
                  : filter == 'Web'
                  ? Icons.web
                  : Icons.phone_android,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            SizedBox(width: 6),
            Text(
              filter,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAttendanceList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Attendance Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                SizedBox(height: 16),
                // Filter buttons for Web/Mobile
                Row(
                  children: [
                    _buildFilterButton('All'),
                    SizedBox(width: 8),
                    _buildFilterButton('Web'),
                    SizedBox(width: 8),
                    _buildFilterButton('Mobile'),
                  ],
                ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _getStudentsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 48),
                        SizedBox(height: 8),
                        Text('Error loading students'),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: Colors.grey,
                          size: 48,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No students found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final allStudents = snapshot.data!.docs;

              // Filter students based on selected filter
              final filteredStudents = allStudents.where((student) {
                if (_studentFilter == 'All') return true;

                final studentData = student.data() as Map<String, dynamic>;
                final platform =
                    (studentData['courseGroup']?.toString() ?? 'mobile')
                        .toLowerCase();

                if (_studentFilter == 'Web') {
                  return platform.contains('web') ||
                      platform.contains('browser');
                } else if (_studentFilter == 'Mobile') {
                  return platform.contains('mobile') ||
                      platform.contains('app') ||
                      platform.contains('android') ||
                      platform.contains('ios') ||
                      !platform.contains(
                        'web',
                      ); // Default to mobile if not specified
                }
                return true;
              }).toList();

              // Sort students manually by lastName
              filteredStudents.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aLastName = aData['lastName'] ?? '';
                final bLastName = bData['lastName'] ?? '';
                return aLastName.compareTo(bLastName);
              });

              if (filteredStudents.isEmpty) {
                return Container(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _studentFilter == 'Web'
                              ? Icons.web
                              : Icons.phone_android,
                          color: Colors.grey,
                          size: 48,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No ${_studentFilter.toLowerCase()} students found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: filteredStudents.length,
                separatorBuilder: (context, index) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final student = filteredStudents[index];
                  return _buildStudentAttendanceItem(student);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAttendanceItem(DocumentSnapshot student) {
    final studentData = student.data() as Map<String, dynamic>;
    final studentName =
        '${studentData['firstName'] ?? ''} ${studentData['lastName'] ?? ''}'
            .trim();
    final platform = (studentData['courseGroup']?.toString() ?? 'mobile')
        .toLowerCase();
    final platformIcon =
        platform.contains('web') || platform.contains('browser')
        ? Icons.web
        : Icons.phone_android;
    final platformText =
        platform.contains('web') || platform.contains('browser')
        ? 'Web'
        : 'Mobile';

    return StreamBuilder<QuerySnapshot>(
      stream: _getStudentAttendanceStream(student.id),
      builder: (context, snapshot) {
        final attendanceStatus = _getStudentAttendanceStatus(
          snapshot.data?.docs,
        );

        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: attendanceStatus['color'],
            child: Icon(
              attendanceStatus['icon'],
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  studentName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
              // At Risk Indicator - only show for at-risk students
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .doc(student.id)
                    .collection('at-risk')
                    .limit(1)
                    .snapshots(),
                builder: (context, atRiskSnapshot) {
                  bool isAtRisk = false;

                  if (atRiskSnapshot.hasData &&
                      atRiskSnapshot.data!.docs.isNotEmpty) {
                    final doc = atRiskSnapshot.data!.docs.first;
                    final data = doc.data() as Map<String, dynamic>;

                    // Apply the same At Risk criteria as in the progress indicator
                    final weeklyAbsences = data['weeklyAbsences'] ?? 0;
                    final monthlyAbsences = data['monthlyAbsences'] ?? 0;
                    final weeklyRisk =
                        data['riskFactors']?['weeklyRisk'] ?? false;
                    final monthlyRisk =
                        data['riskFactors']?['monthlyRisk'] ?? false;

                    final meetsWeeklyRisk = weeklyAbsences >= 2 || weeklyRisk;
                    final meetsMonthlyRisk =
                        monthlyAbsences >= 8 || monthlyRisk;
                    isAtRisk = meetsWeeklyRisk || meetsMonthlyRisk;
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show At Risk indicator only if student is at risk
                      if (isAtRisk) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          margin: EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFF9B59B6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Color(0xFF9B59B6).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning,
                                size: 10,
                                color: Color(0xFF9B59B6),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'AT RISK',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF9B59B6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Platform indicator (always shown)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: platform.contains('web')
                              ? Color(0xFF3498DB).withOpacity(0.1)
                              : Color(0xFF27AE60).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: platform.contains('web')
                                ? Color(0xFF3498DB).withOpacity(0.3)
                                : Color(0xFF27AE60).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              platformIcon,
                              size: 12,
                              color: platform.contains('web')
                                  ? Color(0xFF3498DB)
                                  : Color(0xFF27AE60),
                            ),
                            SizedBox(width: 4),
                            Text(
                              platformText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: platform.contains('web')
                                    ? Color(0xFF3498DB)
                                    : Color(0xFF27AE60),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          subtitle: Text(
            attendanceStatus['status'],
            style: TextStyle(color: attendanceStatus['color'], fontSize: 12),
          ),
          trailing: Icon(Icons.chevron_right, color: Color(0xFF95A5A6)),
          onTap: () => _showStudentDetails(student.id, studentName),
        );
      },
    );
  }

  // Streams and Data Methods
  Stream<QuerySnapshot> _getTodayAttendanceStream() {
    final today = DateTime.now();
    final dateId = _formatDateId(today);

    print('Querying attendance for dateId: $dateId');

    // Debug: Check current user and role
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print('Current user UID: ${currentUser.uid}');
      print('Current user email: ${currentUser.email}');

      // Check user role in Firestore
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get()
          .then((doc) {
            if (doc.exists) {
              print('User role: ${doc.data()?['role']}');
              print('User data: ${doc.data()}');
            } else {
              print('User document does not exist in Firestore!');
            }
          })
          .catchError((error) {
            print('Error fetching user role: $error');
          });
    }

    return FirebaseFirestore.instance
        .collectionGroup('days')
        .where('dayId', isEqualTo: dateId)
        .snapshots()
        .handleError((error) {
          print('Attendance stream error: $error');
          return Stream.empty();
        });
  }

  Stream<QuerySnapshot> _getAttendanceStream() {
    final now = DateTime.now();
    String startDateId;
    String endDateId;

    switch (_selectedPeriod) {
      case 'Today':
        final today = DateTime(now.year, now.month, now.day);
        // Only show today's data if it's a weekday (school operates Monday-Friday only)
        if (_isWeekday(today)) {
          startDateId = _formatDateId(today);
          endDateId = startDateId;
        } else {
          // If it's weekend, show the most recent weekday (Friday)
          final lastWeekday = _getLastWeekday(today);
          startDateId = _formatDateId(lastWeekday);
          endDateId = startDateId;
        }
        break;
      case 'This Week':
        final weekdayDates = _getWeekdaysInRange(
          _getWeekStartDate(now),
          _getWeekEndDate(now),
        );
        if (weekdayDates.isNotEmpty) {
          startDateId = _formatDateId(weekdayDates.first);
          endDateId = _formatDateId(weekdayDates.last);
        } else {
          // Fallback to today if no weekdays found
          final today = DateTime(now.year, now.month, now.day);
          startDateId = _formatDateId(today);
          endDateId = startDateId;
        }
        break;
      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        final weekdayDates = _getWeekdaysInRange(startOfMonth, endOfMonth);
        if (weekdayDates.isNotEmpty) {
          startDateId = _formatDateId(weekdayDates.first);
          endDateId = _formatDateId(weekdayDates.last);
        } else {
          startDateId = _formatDateId(startOfMonth);
          endDateId = _formatDateId(endOfMonth);
        }
        break;
      default:
        final today = DateTime(now.year, now.month, now.day);
        startDateId = _formatDateId(today);
        endDateId = startDateId;
    }

    return FirebaseFirestore.instance
        .collectionGroup('days')
        .where('dayId', isGreaterThanOrEqualTo: startDateId)
        .where('dayId', isLessThanOrEqualTo: endDateId)
        .snapshots();
  }

  Stream<QuerySnapshot> _getStudentsStream() {
    print('Querying students...');
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .snapshots()
        .handleError((error) {
          print('Students stream error: $error');
          return Stream.empty();
        });
  }

  Stream<QuerySnapshot> _getStudentAttendanceStream(String studentId) {
    final now = DateTime.now();
    String startDateId;
    String endDateId;

    switch (_selectedPeriod) {
      case 'Today':
        final today = DateTime(now.year, now.month, now.day);
        startDateId = _formatDateId(today);
        endDateId = startDateId;
        break;
      case 'This Week':
        final weekday = now.weekday;
        final startOfWeek = now.subtract(Duration(days: weekday - 1));
        final endOfWeek = startOfWeek.add(Duration(days: 6));
        startDateId = _formatDateId(
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
        );
        endDateId = _formatDateId(
          DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day),
        );
        break;
      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        startDateId = _formatDateId(startOfMonth);
        endDateId = _formatDateId(endOfMonth);
        break;
      default:
        final today = DateTime(now.year, now.month, now.day);
        startDateId = _formatDateId(today);
        endDateId = startDateId;
    }

    return FirebaseFirestore.instance
        .collection('attendance')
        .doc(studentId)
        .collection('days')
        .where('dayId', isGreaterThanOrEqualTo: startDateId)
        .where('dayId', isLessThanOrEqualTo: endDateId)
        .snapshots();
  }

  // Helper method to format date as YYYY-MM-DD (matching the attendance service format)
  String _formatDateId(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  // Weekday Helper Methods
  bool _isWeekday(DateTime date) {
    // Monday = 1, Tuesday = 2, ..., Friday = 5, Saturday = 6, Sunday = 7
    return date.weekday >= 1 && date.weekday <= 5;
  }

  DateTime _getLastWeekday(DateTime date) {
    DateTime current = date;
    while (!_isWeekday(current)) {
      current = current.subtract(Duration(days: 1));
    }
    return current;
  }

  DateTime _getWeekStartDate(DateTime date) {
    // Get Monday of the week
    final daysSinceMonday = date.weekday - 1;
    return date.subtract(Duration(days: daysSinceMonday));
  }

  DateTime _getWeekEndDate(DateTime date) {
    // Get Sunday of the week
    final daysUntilSunday = 7 - date.weekday;
    return date.add(Duration(days: daysUntilSunday));
  }

  List<DateTime> _getWeekdaysInRange(DateTime start, DateTime end) {
    List<DateTime> weekdays = [];
    DateTime current = start;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      if (_isWeekday(current)) {
        weekdays.add(current);
      }
      current = current.add(Duration(days: 1));
    }

    return weekdays;
  }

  // Student Creation Date Helper
  Future<DateTime?> _getStudentCreationDate(String studentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final createdAt = data['createdAt'] as Timestamp?;
        return createdAt?.toDate();
      }
    } catch (e) {
      print('Error getting student creation date: $e');
    }
    return null;
  }

  // Filter attendance records to only include weekday records (Monday-Friday)
  // This ensures attendance tracking only occurs during school operating days
  List<DocumentSnapshot> _filterWeekdayRecords(List<DocumentSnapshot> records) {
    return records.where((record) {
      final data = record.data() as Map<String, dynamic>;
      final dayId = data['dayId'] as String?;
      if (dayId != null) {
        final recordDate = DateTime.tryParse(dayId);
        return recordDate != null && _isWeekday(recordDate);
      }
      return false;
    }).toList();
  }

  // Filter attendance records to only include records after student creation date
  // This ensures new students' attendance tracking starts from their enrollment date
  Future<List<DocumentSnapshot>> _filterRecordsByStudentCreation(
    List<DocumentSnapshot> records,
    String studentId,
  ) async {
    final creationDate = await _getStudentCreationDate(studentId);
    if (creationDate == null) return records;

    return records.where((record) {
      final data = record.data() as Map<String, dynamic>;
      final dayId = data['dayId'] as String?;
      if (dayId != null) {
        final recordDate = DateTime.tryParse(dayId);
        return recordDate != null &&
            (recordDate.isAfter(creationDate) ||
                recordDate.isAtSameMomentAs(creationDate));
      }
      return false;
    }).toList();
  }

  // Calculation Methods
  Map<String, int> _calculateTodayStats(
    List<DocumentSnapshot> attendanceRecords,
    int totalStudents,
  ) {
    // Filter to only include weekday records
    final weekdayRecords = _filterWeekdayRecords(attendanceRecords);

    Set<String> presentUserIds = {};
    Set<String> lateUserIds = {};
    Set<String> earlyUserIds = {};

    for (final record in weekdayRecords) {
      final data = record.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'absent';
      final userId =
          record.reference.parent.parent?.id; // Get userId from document path

      // Count unique users who are present (including late)
      if ((status == 'present' || status == 'late' || status == 'early') &&
          userId != null) {
        presentUserIds.add(userId);
      }

      // Count unique users who were late (not individual late records)
      if (userId != null && (status == 'late' || data['lateReason'] != null)) {
        lateUserIds.add(userId);
      }

      // Count unique users who left early (clock out before 5 PM)
      if (userId != null) {
        final clockOutTime =
            data['outAt'] as Timestamp? ?? data['clockOutAt'] as Timestamp?;
        if (clockOutTime != null) {
          final clockOut = clockOutTime.toDate();
          final expectedEnd = DateTime(
            clockOut.year,
            clockOut.month,
            clockOut.day,
            17,
            0,
          ); // 5 PM
          if (clockOut.isBefore(expectedEnd)) {
            earlyUserIds.add(userId);
          }
        }
      }
    }

    final present = presentUserIds.length;
    final absent = totalStudents - present;
    final late = lateUserIds.length;
    final early = earlyUserIds.length;

    return {'late': late, 'early': early, 'present': present, 'absent': absent};
  }

  Map<String, int> _calculateAttendanceStats(
    List<DocumentSnapshot> attendanceRecords,
    int totalStudents,
  ) {
    // Filter to only include weekday records
    final weekdayRecords = _filterWeekdayRecords(attendanceRecords);

    Set<String> uniqueStudents = {};
    Set<String> lateStudents = {};

    for (final record in weekdayRecords) {
      final data = record.data() as Map<String, dynamic>;
      final userId =
          record.reference.parent.parent?.id; // Get userId from document path
      final status = data['status'] as String? ?? 'absent';

      if (userId != null &&
          (status == 'present' || status == 'late' || status == 'early')) {
        uniqueStudents.add(userId);
      }

      // Count unique students who were late (not individual late records)
      if (userId != null && (status == 'late' || data['lateReason'] != null)) {
        lateStudents.add(userId);
      }
    }

    final present = uniqueStudents.length;
    final absent = totalStudents - present;
    final late = lateStudents.length;

    return {
      'present': present,
      'absent': absent,
      'late': late,
      'total': totalStudents,
    };
  }

  Map<String, dynamic> _getStudentAttendanceStatus(
    List<DocumentSnapshot>? attendanceRecords,
  ) {
    if (attendanceRecords == null || attendanceRecords.isEmpty) {
      return {
        'status': 'Absent',
        'color': Color(0xFFE74C3C),
        'icon': Icons.cancel,
      };
    }

    // Get the most recent attendance record
    final latestRecord = attendanceRecords.first;
    final data = latestRecord.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'absent';

    switch (status) {
      case 'late':
        return {
          'status': 'Late',
          'color': Color(0xFFFF9800),
          'icon': Icons.schedule,
        };
      case 'early':
        return {
          'status': 'Early',
          'color': Color(0xFF3498DB),
          'icon': Icons.access_time,
        };
      case 'present':
        return {
          'status': 'Present',
          'color': Color(0xFF27AE60),
          'icon': Icons.check_circle,
        };
      case 'absent':
      default:
        return {
          'status': 'Absent',
          'color': Color(0xFFE74C3C),
          'icon': Icons.cancel,
        };
    }
  }

  // Action Methods
  void _showLateStudentsList(List<DocumentSnapshot> attendanceRecords) {
    final lateStudents = attendanceRecords.where((record) {
      final data = record.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'absent';
      return status == 'late' || data['lateReason'] != null;
    }).toList();

    _showStudentListDialog('Late Arrivals', lateStudents, Color(0xFFFF9800));
  }

  void _showEarlyStudentsList(List<DocumentSnapshot> attendanceRecords) {
    final earlyStudents = attendanceRecords.where((record) {
      final data = record.data() as Map<String, dynamic>;
      final clockOutTime =
          data['outAt'] as Timestamp? ?? data['clockOutAt'] as Timestamp?;
      if (clockOutTime != null) {
        final clockOut = clockOutTime.toDate();
        final expectedEnd = DateTime(
          clockOut.year,
          clockOut.month,
          clockOut.day,
          17,
          0,
        );
        return clockOut.isBefore(expectedEnd);
      }
      return false;
    }).toList();

    _showStudentListDialog(
      'Early Departures',
      earlyStudents,
      Color(0xFFE74C3C),
    );
  }

  void _showPresentStudentsList(List<DocumentSnapshot> attendanceRecords) {
    final presentStudents = attendanceRecords.where((record) {
      final data = record.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'absent';
      return status == 'present' || status == 'late' || status == 'early';
    }).toList();

    _showStudentListDialog(
      'Present Students',
      presentStudents,
      Color(0xFF27AE60),
    );
  }

  void _showStudentListDialog(
    String title,
    List<DocumentSnapshot> records,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.people, color: color, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            // Content
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No students found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final userId = record.reference.parent.parent?.id ?? '';

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: color.withOpacity(0.2),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                color,
                                              ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Loading...'),
                                  ],
                                ),
                              );
                            }

                            final userData =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            final name =
                                '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}'
                                    .trim();

                            final recordData =
                                record.data() as Map<String, dynamic>;
                            final clockInTime =
                                (recordData['inAt'] ?? recordData['clockInAt'])
                                    as Timestamp?;

                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(
                                    context,
                                  ); // Close the bottom sheet
                                  _showStudentDetails(userId, name);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: color.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: color.withOpacity(0.2),
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 16,
                                                color: Color(0xFF2C3E50),
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              clockInTime != null
                                                  ? DateFormat.jm().format(
                                                      clockInTime.toDate(),
                                                    )
                                                  : 'No clock in time',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.access_time,
                                        color: color,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentDetails(String studentId, String studentName) {
    Navigator.pushNamed(context, '/admin');
  }

  void _showAbsentStudentsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.person_off, color: Color(0xFFE74C3C), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Absent Students',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(thickness: 1),
            // Content
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getAttendanceStream(),
                builder: (context, attendanceSnapshot) {
                  if (attendanceSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _getStudentsStream(),
                    builder: (context, studentsSnapshot) {
                      if (studentsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      if (!attendanceSnapshot.hasData ||
                          !studentsSnapshot.hasData) {
                        return Center(child: Text('No data available'));
                      }

                      final attendanceRecords = attendanceSnapshot.data!.docs;
                      final allStudents = studentsSnapshot.data!.docs;

                      // Get present student IDs from attendance records
                      Set<String> presentStudentIds = {};
                      for (final record in attendanceRecords) {
                        final userId = record.reference.parent.parent?.id;
                        if (userId != null) {
                          presentStudentIds.add(userId);
                        }
                      }

                      // Find absent students (those not in attendance records)
                      final absentStudents = allStudents.where((student) {
                        return !presentStudentIds.contains(student.id);
                      }).toList();

                      if (absentStudents.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 64,
                                color: Color(0xFF27AE60),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No absent students!',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF27AE60),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.all(16),
                        itemCount: absentStudents.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final student = absentStudents[index];
                          final studentData =
                              student.data() as Map<String, dynamic>;
                          final firstName = studentData['firstName'] ?? '';
                          final lastName = studentData['lastName'] ?? '';
                          final name = '$firstName $lastName'.trim();

                          return Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(0xFFE9ECEF),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Color(
                                    0xFFE74C3C,
                                  ).withOpacity(0.2),
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: Color(0xFFE74C3C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name.isNotEmpty
                                            ? name
                                            : 'Unknown Student',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Color(0xFF2C3E50),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'No attendance record',
                                        style: TextStyle(
                                          color: Color(0xFF6C757D),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.schedule,
                                  color: Color(0xFFE74C3C),
                                  size: 20,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAtRiskStudentsBottomSheet(
    List<Map<String, dynamic>> atRiskStudents,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Color(0xFF9B59B6), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'At Risk Students',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(thickness: 1),
            // Content
            Expanded(
              child: atRiskStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 64,
                            color: Color(0xFF27AE60),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No students at risk!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF27AE60),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.all(16),
                      itemCount: atRiskStudents.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final student = atRiskStudents[index];
                        final studentId = student['id'] as String;
                        final weeklyAbsences = student['weeklyAbsences'] as int;
                        final monthlyAbsences =
                            student['monthlyAbsences'] as int;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(studentId)
                              .get(),
                          builder: (context, snapshot) {
                            final studentData =
                                snapshot.data?.data() as Map<String, dynamic>?;
                            final firstName = studentData?['firstName'] ?? '';
                            final lastName = studentData?['lastName'] ?? '';
                            final name = '$firstName $lastName'.trim();

                            return Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Color(0xFFE9ECEF),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Color(
                                      0xFF9B59B6,
                                    ).withOpacity(0.2),
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: Color(0xFF9B59B6),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.isNotEmpty ? name : 'Loading...',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Absences: Weekly $weeklyAbsences • Monthly $monthlyAbsences',
                                          style: TextStyle(
                                            color: Color(0xFF6C757D),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.warning,
                                    color: Color(0xFF9B59B6),
                                    size: 20,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
