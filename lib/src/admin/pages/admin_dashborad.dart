import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _selectedPeriod = 'Today';
  List<String> _periods = ['Today', 'This Week', 'This Month'];
  String _studentFilter = 'All'; // 'All', 'Web', 'Mobile'

  PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
                        () => _showAbsentStudentsList(
                          attendanceRecords,
                          studentsSnapshot.data!.docs,
                        ),
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
    return Container(
      padding: EdgeInsets.all(20),
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
          Text(
            '$_selectedPeriod Attendance Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _getAttendanceStream(),
            builder: (context, attendanceSnapshot) {
              if (attendanceSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (attendanceSnapshot.hasError) {
                print('Attendance overview error: ${attendanceSnapshot.error}');
                print('Error details: ${attendanceSnapshot.error.runtimeType}');
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
                    print('Students overview error: ${studentsSnapshot.error}');
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
                  final attendanceRecords = attendanceSnapshot.data?.docs ?? [];
                  final stats = _calculateAttendanceStats(
                    attendanceRecords,
                    totalStudents,
                  );

                  print(
                    'Overview - Total students: $totalStudents, Records: ${attendanceRecords.length}',
                  );

                  return Column(
                    children: [
                      // Horizontal scrollable content
                      Container(
                        height: 200,
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          children: [
                            // Page 1: Attendance Progress Indicators
                            _buildAttendanceProgressPage(stats),

                            // Page 2: Weekly Trend
                            _buildWeeklyTrendPage(),

                            // Page 3: Frequently Late Students
                            _buildFrequentlyLatePage(),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Page dots indicator
                      _buildPageIndicator(),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
    String label,
    int value,
    int total,
    Color color,
  ) {
    final percentage = total > 0 ? (value / total) : 0.0;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
        SizedBox(width: 12),
        Text(
          '$value',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  // New page-based methods for horizontal scrolling
  Widget _buildAttendanceProgressPage(Map<String, int> stats) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendPage() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: _buildWeeklyTrendComparison(),
    );
  }

  Widget _buildFrequentlyLatePage() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: _buildFrequentlyLateStudents(),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? Color(0xFF3498DB)
                : Colors.grey.withOpacity(0.4),
          ),
        );
      }),
    );
  }

  // New: Weekly Trend Comparison Widget
  Widget _buildWeeklyTrendComparison() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getAllAttendanceStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildTrendLoading();
        }

        if (snapshot.hasError) {
          return _buildTrendError('Error loading trend data');
        }

        final attendanceRecords = snapshot.data?.docs ?? [];
        final trendData = _calculateWeeklyTrend(attendanceRecords);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            width: 350, // Give it a fixed width for horizontal scrolling
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
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
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
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
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
          ),
        );
      },
    );
  }

  // New: Frequently Late Students Widget
  Widget _buildFrequentlyLateStudents() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getAllAttendanceStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildFrequentlyLateLoading();
        }

        if (snapshot.hasError) {
          return _buildFrequentlyLateError('Error loading late students');
        }

        final attendanceRecords = snapshot.data?.docs ?? [];
        final frequentlyLateStudents = _getFrequentlyLateStudents(
          attendanceRecords,
        );

        return Container(
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
                  Icon(Icons.warning_amber, color: Color(0xFFFF9800), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Frequently Late (≥2 times)',
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
                        Icon(Icons.celebration, color: Colors.green, size: 32),
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
                  children: frequentlyLateStudents.take(5).map((student) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Color(0xFFFF9800).withOpacity(0.2),
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

              if (frequentlyLateStudents.length > 5)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${frequentlyLateStudents.length - 5} more students',
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
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        .collectionGroup('days')
        .where('dayId', isGreaterThanOrEqualTo: startDateId)
        .where('dayId', isLessThanOrEqualTo: endDateId)
        .snapshots();
  }

  // New: Get all attendance records for trend analysis
  Stream<QuerySnapshot> _getAllAttendanceStream() {
    return FirebaseFirestore.instance.collectionGroup('days').snapshots();
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

  // New: Calculate weekly trend data
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

  // New: Get frequently late students (≥2 lates)
  List<Map<String, dynamic>> _getFrequentlyLateStudents(
    List<DocumentSnapshot> allRecords,
  ) {
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

          // Store student name if not already stored
          if (!studentNames.containsKey(userId)) {
            // In a real implementation, you would fetch the student name from users collection
            // For now, we'll use a placeholder
            studentNames[userId] = 'Student $userId';
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

  // Calculation Methods
  Map<String, int> _calculateTodayStats(
    List<DocumentSnapshot> attendanceRecords,
    int totalStudents,
  ) {
    int late = 0;
    int early = 0;
    int present = 0;
    Set<String> presentUserIds = {};

    for (final record in attendanceRecords) {
      final data = record.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'absent';
      final userId =
          record.reference.parent.parent?.id; // Get userId from document path

      // Count unique users who are present (including late)
      if ((status == 'present' || status == 'late' || status == 'early') &&
          userId != null) {
        presentUserIds.add(userId);
      }

      // Check if late (based on status or lateReason)
      if (status == 'late' || data['lateReason'] != null) {
        late++;
      }

      // Check if early departure (clock out before 5 PM)
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
          early++;
        }
      }
    }

    present = presentUserIds.length;
    final absent = totalStudents - present;

    return {'late': late, 'early': early, 'present': present, 'absent': absent};
  }

  Map<String, int> _calculateAttendanceStats(
    List<DocumentSnapshot> attendanceRecords,
    int totalStudents,
  ) {
    int late = 0;
    Set<String> uniqueStudents = {};

    for (final record in attendanceRecords) {
      final data = record.data() as Map<String, dynamic>;
      final userId =
          record.reference.parent.parent?.id; // Get userId from document path
      final status = data['status'] as String? ?? 'absent';

      if (userId != null &&
          (status == 'present' || status == 'late' || status == 'early')) {
        uniqueStudents.add(userId);
      }

      if (status == 'late' || data['lateReason'] != null) {
        late++;
      }
    }

    final present = uniqueStudents.length;
    final absent = totalStudents - present;

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

  void _showAbsentStudentsList(
    List<DocumentSnapshot> attendanceRecords,
    List<DocumentSnapshot> allStudents,
  ) {
    // Get list of present student IDs
    Set<String> presentStudentIds = {};
    for (final record in attendanceRecords) {
      final userId = record.reference.parent.parent?.id;
      if (userId != null) {
        presentStudentIds.add(userId);
      }
    }

    // Find absent students
    final absentStudents = allStudents.where((student) {
      return !presentStudentIds.contains(student.id);
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.people, color: Color(0xFF95A5A6)),
            SizedBox(width: 8),
            Text('Absent Students'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: absentStudents.isEmpty
              ? Center(
                  child: Text(
                    'No absent students found',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: absentStudents.length,
                  itemBuilder: (context, index) {
                    final student = absentStudents[index];
                    final studentData = student.data() as Map<String, dynamic>;
                    final name =
                        '${studentData['firstName'] ?? ''} ${studentData['lastName'] ?? ''}'
                            .trim();

                    return ListTile(
                      title: Text(name),
                      subtitle: Text('No attendance record'),
                      leading: CircleAvatar(
                        backgroundColor: Color(0xFF95A5A6).withOpacity(0.2),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Color(0xFF95A5A6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Color(0xFF95A5A6),
                      ),
                      onTap: () => _showStudentDetails(student.id, name),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
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
}
