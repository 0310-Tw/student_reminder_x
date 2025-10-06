// file: lib/src/admin/pages/attendance_admin_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:students_reminder/src/shared/routes.dart';
import '../../services/attendance_service.dart';
import '../../shared/misc.dart';

class AttendanceAdminPage extends StatefulWidget {
  const AttendanceAdminPage({super.key});

  @override
  State<AttendanceAdminPage> createState() => _AttendanceAdminPageState();
}

class _AttendanceAdminPageState extends State<AttendanceAdminPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isAdmin = false;
  bool _isLoading = true;
  String _platformFilter = 'All'; // 'All', 'Web', 'Mobile'

  // Real-time synchronization
  StreamSubscription<QuerySnapshot>? _attendanceSubscription;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAdminRole() async {
    final isAdmin = await AttendanceService.isCurrentUserAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _isLoading = false;
      });

      if (_isAdmin) {
        _setupRealTimeSync();
      }
    }
  }

  void _setupRealTimeSync() {
    // Listen to all attendance records for real-time updates
    _attendanceSubscription = FirebaseFirestore.instance
        .collection('attendance')
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            // Refresh the UI when attendance data changes
            setState(() {});
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Access Denied'),
          backgroundColor: Color(0xFF1A237E),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Container(
            margin: EdgeInsets.all(32),
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.security,
                    size: 48,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Admin Access Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3440),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You do not have permission to access this page.',
                  style: TextStyle(color: Color(0xFF6C7B7F), fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor: Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      backgroundColor: Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3F51B5), Color(0xFF1A237E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          _buildDateRangePicker(),
          _buildPlatformFilter(),
          Expanded(child: _buildStudentsList()),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF1976D2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_month,
                color: Color(0xFF1976D2),
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date Range Selection',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2E3440),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${_formatDisplayDate(_startDate)} - ${_formatDisplayDate(_endDate)}',
                    style: TextStyle(color: Color(0xFF6C7B7F), fontSize: 14),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showDateRangePicker,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1976D2),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.date_range, size: 20),
              label: const Text('Select Range'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by Platform',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF2E3440),
            ),
          ),
          SizedBox(height: 12),
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
    );
  }

  Widget _buildFilterButton(String filter) {
    final isSelected = _platformFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _platformFilter = filter;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF1976D2) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Color(0xFF1976D2) : Colors.grey[300]!,
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

  Widget _buildStudentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: AttendanceService.getStudentsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allUsers = snapshot.data?.docs ?? [];

        // Filter out admin users - only show non-admin users in attendance
        final students = allUsers.where((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          final userRole = userData['role'] as String?;

          // First filter: exclude admin users
          if (userRole == 'admin') return false;

          // Second filter: platform filtering
          if (_platformFilter != 'All') {
            // Use courseGroup field (which contains 'web' or 'mobile') instead of platform
            final courseGroup =
                (userData['courseGroup']?.toString() ?? 'mobile').toLowerCase();

            if (_platformFilter == 'Web') {
              return courseGroup.contains('web') ||
                  courseGroup.contains('browser');
            } else if (_platformFilter == 'Mobile') {
              return courseGroup.contains('mobile') ||
                  courseGroup.contains('app') ||
                  courseGroup.contains('android') ||
                  courseGroup.contains('ios') ||
                  !courseGroup.contains(
                    'web',
                  ); // Default to mobile if not specified
            }
          }

          return true;
        }).toList();

        if (students.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No students found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Make sure users have been properly registered',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            final studentData = student.data() as Map<String, dynamic>;

            return _buildStudentCard(student.id, studentData);
          },
        );
      },
    );
  }

  Widget _buildStudentCard(
    String studentUid,
    Map<String, dynamic> studentData,
  ) {
    final studentName =
        '${studentData['firstName'] ?? ''} ${studentData['lastName'] ?? ''}'
            .trim()
            .isEmpty
        ? 'Unknown Student'
        : '${studentData['firstName'] ?? ''} ${studentData['lastName'] ?? ''}'
              .trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          childrenPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(0xFF1976D2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.person, color: Color(0xFF1976D2), size: 24),
          ),
          title: Text(
            studentName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFF2E3440),
            ),
          ),
          subtitle: Text(
            studentData['email'] ?? 'No email',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey[600],
            size: 24,
          ),
          children: [_buildAttendanceList(studentUid)],
        ),
      ),
    );
  }

  Widget _buildAttendanceList(String studentUid) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: AttendanceService.getStudentAttendanceStream(
          studentUid,
          _startDate,
          _endDate,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Error loading attendance: ${snapshot.error}',
                  style: TextStyle(color: Colors.red[600]),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final attendanceDocs = snapshot.data?.docs ?? [];

          // Generate all dates in range for display
          final allDates = _generateDateRange(_startDate, _endDate);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF2E3440),
                  ),
                ),
                SizedBox(height: 12),
                ...allDates.map((date) {
                  final dateStr = _formatDateString(date);
                  final attendanceDoc = attendanceDocs
                      .cast<QueryDocumentSnapshot?>()
                      .firstWhere(
                        (doc) => doc?.id == dateStr,
                        orElse: () => null,
                      );

                  return _buildAttendanceRow(studentUid, date, attendanceDoc);
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttendanceRow(
    String studentUid,
    DateTime date,
    QueryDocumentSnapshot? doc,
  ) {
    final data = doc?.data() as Map<String, dynamic>? ?? {};
    final dateStr = _formatDateString(date);
    final rawStatus = data['status'] ?? 'not_marked';

    // Normalize status - if user has checked in (early/late), they are present
    String status;
    String? timingStatus;

    if (rawStatus.toString().toLowerCase().startsWith('early')) {
      status = 'present';
      timingStatus = 'early';
    } else if (rawStatus.toString().toLowerCase().startsWith('late')) {
      status = 'present';
      timingStatus = 'late';
    } else if (rawStatus == 'present') {
      status = 'present';
      timingStatus =
          data['timingStatus'] as String?; // Check for explicit timing info
    } else if (rawStatus == 'absent') {
      status = 'absent';
      timingStatus = null;
    } else {
      status = 'not_marked';
      timingStatus = null;
    }

    // Check both new format (inAt) and backward compatibility (clockInAt)
    final clockInAt = (data['inAt'] ?? data['clockInAt']) as Timestamp?;
    final clockOutAt = (data['outAt'] ?? data['clockOutAt']) as Timestamp?;

    // Get late reason from separate field or extract from status for backward compatibility
    String? lateReason = data['lateReason'] as String?;
    if (lateReason == null && rawStatus.contains('— Reason:')) {
      // Extract reason from old format: "late — Reason: text"
      final parts = rawStatus.split('— Reason:');
      if (parts.length > 1) {
        lateReason = parts[1].trim();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Date Section
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDisplayDate(date),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF2E3440),
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        _buildStatusChip(
                          status,
                          isRealTime: _attendanceSubscription != null,
                        ),
                        if (timingStatus != null && status == 'present') ...[
                          const SizedBox(width: 8),
                          _buildTimingBadge(timingStatus),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Time Section
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (clockInAt != null)
                      Row(
                        children: [
                          Icon(Icons.login, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            _formatTime(clockInAt.toDate()),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    if (clockOutAt != null) ...[
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.logout, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            _formatTime(clockOutAt.toDate()),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Action Section - modern dropdown menu
              Container(
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  tooltip: 'Actions',
                  onSelected: (String value) {
                    switch (value) {
                      case 'present':
                        _markPresent(studentUid, dateStr);
                        break;
                      case 'absent':
                        _markAbsent(studentUid, dateStr);
                        break;
                      case 'edit_reason':
                        _editLateReason(studentUid, dateStr, lateReason);
                        break;
                      case 'view_location':
                        _showLocationMap(data);
                        break;
                      case 'geofence': // 👈 your new item
                        Navigator.pushNamed(
                          context,
                          AppRoutes.geofence,
                          arguments: {
                            'studentId': studentUid,
                            'dateId': dateStr,
                          },
                        );
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'present',
                      child: Row(
                        children: [
                          Icon(Icons.check, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('Mark Present'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'absent',
                      child: Row(
                        children: [
                          Icon(Icons.close, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Mark Absent'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'edit_reason',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Reason'),
                        ],
                      ),
                    ),
                    if (data['inLoc'] != null ||
                        data['outLoc'] != null ||
                        data['clockInLoc'] != null ||
                        data['clockOutLoc'] != null)
                      PopupMenuItem<String>(
                        value: 'geofence',
                        child: Row(
                          children: [
                            Icon(
                              Icons.maps_ugc_outlined,
                              color: Colors.indigo,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text('Geofence'),
                          ],
                        ),
                      ),
                    PopupMenuItem<String>(
                      value: 'view_location',
                      child: Row(
                        children: [
                          Icon(Icons.map, color: Colors.purple, size: 18),
                          SizedBox(width: 8),
                          Text('View Location'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Late reason and additional details
          if (lateReason != null) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.orange[700],
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Late Reason:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    lateReason,
                    style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                  ),
                  if (data['lateReasonEditedBy'] != null) ...[
                    SizedBox(height: 4),
                    Text(
                      'Edited by: ${data['lateReasonEditedByName'] ?? 'Admin'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.purple[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, {bool isRealTime = false}) {
    Color color;
    String label;
    IconData? icon;

    switch (status) {
      case 'present':
        color = Colors.green;
        label = 'Present';
        icon = Icons.check_circle;
        break;
      case 'late':
        color = Colors.orange;
        label = 'Late';
        icon = Icons.schedule;
        break;
      case 'early':
        color = Colors.blue;
        label = 'Early';
        icon = Icons.fast_forward;
        break;
      case 'absent':
        color = Colors.red;
        label = 'Absent';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        label = 'Not Marked';
        icon = Icons.help_outline;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isRealTime) ...[
            SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimingBadge(String timingStatus) {
    Color color;
    String label;

    switch (timingStatus) {
      case 'early':
        color = Colors.blue;
        label = 'Early';
        break;
      case 'late':
        color = Colors.orange;
        label = 'Late';
        break;
      default:
        color = Colors.grey;
        label = timingStatus;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color.withOpacity(0.8),
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now().add(Duration(days: 30)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _markPresent(String studentUid, String dateStr) async {
    final confirmed = await _showConfirmationDialog(
      'Mark Present',
      'Mark this student as present for $dateStr?',
    );

    if (!confirmed) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await AttendanceService.adminMarkPresent(user.uid, studentUid, dateStr);
      _showSuccessSnackBar(
        ' Student marked as present for $dateStr and notified',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to mark present: $e');
    }
  }

  Future<void> _markAbsent(String studentUid, String dateStr) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark Absent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mark this student as absent for $dateStr?'),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Mark Absent'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await AttendanceService.adminMarkAbsent(
        user.uid,
        studentUid,
        dateStr,
        reason: reasonController.text.isNotEmpty ? reasonController.text : null,
      );
      _showSuccessSnackBar(
        ' Student marked as absent for $dateStr and notified',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to mark absent: $e');
    }
  }

  Future<void> _editLateReason(
    String studentUid,
    String dateStr,
    String? currentReason,
  ) async {
    final reasonController = TextEditingController(text: currentReason ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Late Reason'),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: 'Late Reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || reasonController.text.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await AttendanceService.adminEditLateReason(
        user.uid,
        studentUid,
        dateStr,
        reasonController.text,
      );
      _showSuccessSnackBar('✅ Late reason updated and user notified');
    } catch (e) {
      _showErrorSnackBar('Failed to update reason: $e');
    }
  }

  Future<void> _showLocationMap(Map<String, dynamic> data) async {
    // Handle both new format (inLoc) and backward compatibility (clockInLoc)
    dynamic clockInLocData = data['inLoc'] ?? data['clockInLoc'];
    dynamic clockOutLocData = data['outLoc'] ?? data['clockOutLoc'];

    // Convert location data to GeoPoint if it's in map format
    GeoPoint? clockInLoc;
    GeoPoint? clockOutLoc;

    if (clockInLocData != null) {
      if (clockInLocData is GeoPoint) {
        clockInLoc = clockInLocData;
      } else if (clockInLocData is Map) {
        final lat = clockInLocData['lat']?.toDouble();
        final lng = clockInLocData['lng']?.toDouble();
        if (lat != null && lng != null) {
          clockInLoc = GeoPoint(lat, lng);
        }
      }
    }

    if (clockOutLocData != null) {
      if (clockOutLocData is GeoPoint) {
        clockOutLoc = clockOutLocData;
      } else if (clockOutLocData is Map) {
        final lat = clockOutLocData['lat']?.toDouble();
        final lng = clockOutLocData['lng']?.toDouble();
        if (lat != null && lng != null) {
          clockOutLoc = GeoPoint(lat, lng);
        }
      }
    }

    final clockInTime = data['inAt'] ?? data['clockInAt'] ?? data['clockIn'];
    final clockOutTime =
        data['outAt'] ?? data['clockOutAt'] ?? data['clockOut'];
    final lateReason = data['lateReason'] as String?;

    // If no location data available, show the old dialog
    if (clockInLoc == null && clockOutLoc == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.location_off, color: Colors.grey),
              SizedBox(width: 8),
              Text('No Location Data'),
            ],
          ),
          content: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_off, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'No location data available',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'This attendance record was created without location tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
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
      return;
    }

    // Show map dialog with Google Maps
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF2C3E50),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Attendance Locations',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Map
              Expanded(
                flex: 3,
                child: _buildLocationMap(clockInLoc, clockOutLoc),
              ),
              // Location details
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (clockInLoc != null) ...[
                          _buildLocationCard(
                            'Clock In Location',
                            Icons.login,
                            Colors.green,
                            clockInLoc,
                            clockInTime,
                            lateReason,
                          ),
                          SizedBox(height: 12),
                        ],
                        if (clockOutLoc != null) ...[
                          _buildLocationCard(
                            'Clock Out Location',
                            Icons.logout,
                            Colors.orange,
                            clockOutLoc,
                            clockOutTime,
                            null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationMap(GeoPoint? clockInLoc, GeoPoint? clockOutLoc) {
    Set<Marker> markers = {};
    LatLng center;

    if (clockInLoc != null) {
      markers.add(
        Marker(
          markerId: MarkerId('clock_in'),
          position: LatLng(clockInLoc.latitude, clockInLoc.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: 'Clock In Location'),
        ),
      );
      center = LatLng(clockInLoc.latitude, clockInLoc.longitude);
    } else {
      center = LatLng(clockOutLoc!.latitude, clockOutLoc.longitude);
    }

    if (clockOutLoc != null) {
      markers.add(
        Marker(
          markerId: MarkerId('clock_out'),
          position: LatLng(clockOutLoc.latitude, clockOutLoc.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: 'Clock Out Location'),
        ),
      );
    }

    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        // Multiple attempts to ensure zoom works
        Future.delayed(Duration(milliseconds: 100), () {
          controller.animateCamera(CameraUpdate.newLatLngZoom(center, 19.0));
        });
        Future.delayed(Duration(milliseconds: 1000), () {
          controller.animateCamera(CameraUpdate.newLatLngZoom(center, 19.0));
        });
      },
      initialCameraPosition: CameraPosition(target: center, zoom: 19.0),
      markers: markers,
      mapType: MapType.normal,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      minMaxZoomPreference: MinMaxZoomPreference(15.0, 21.0),
    );
  }

  Widget _buildLocationCard(
    String title,
    IconData icon,
    Color color,
    GeoPoint location,
    dynamic time,
    String? reason,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              SizedBox(width: 4),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 8),
          Text('📍 Coordinates:'),
          Text(
            '   ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
          ),
          if (time != null) ...[
            SizedBox(height: 4),
            Text('🕐 Time: ${_formatTimestamp(time)}'),
          ],
          if (reason != null && reason.isNotEmpty) ...[
            SizedBox(height: 4),
            Text('📝 Late Reason: $reason'),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return timestamp.toString();
    }

    return '${_formatDisplayDate(dateTime)} at ${_formatTime(dateTime)}';
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showSuccessSnackBar(String message) {
    displaySnackBar(context, message, backgroundColor: Colors.green);
  }

  void _showErrorSnackBar(String message) {
    displaySnackBar(context, message, backgroundColor: Colors.red);
  }

  List<DateTime> _generateDateRange(DateTime start, DateTime end) {
    final dates = <DateTime>[];
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDate)) {
      dates.add(current);
      current = current.add(Duration(days: 1));
    }

    return dates;
  }

  String _formatDisplayDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateString(DateTime date) {
    // Use the same format as JmTime.dateId (YYYY-MM-DD)
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
