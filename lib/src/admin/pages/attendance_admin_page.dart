// file: lib/src/admin/pages/attendance_admin_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          title: const Text('Access Denied'),
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
        backgroundColor: Color(0xFF1A237E), // Deep indigo
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      backgroundColor: Color(0xFFF8F9FA), // Light gray background
      body: Column(
        children: [
          // Professional header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF3F51B5),
                  Color(0xFF1A237E),
                ], // Indigo gradient
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
          return userRole != 'admin'; // Exclude admin users
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          '${studentData['firstName'] ?? ''} ${studentData['lastName'] ?? ''}'
                  .trim()
                  .isEmpty
              ? 'Unknown Student'
              : '${studentData['firstName'] ?? ''} ${studentData['lastName'] ?? ''}'
                    .trim(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(studentData['email'] ?? 'No email'),
        children: [_buildAttendanceList(studentUid)],
      ),
    );
  }

  Widget _buildAttendanceList(String studentUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: AttendanceService.getStudentAttendanceStream(
        studentUid,
        _startDate,
        _endDate,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error loading attendance: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final attendanceDocs = snapshot.data?.docs ?? [];

        // Generate all dates in range for display
        final allDates = _generateDateRange(_startDate, _endDate);

        return Column(
          children: allDates.map((date) {
            final dateStr = _formatDateString(date);
            final attendanceDoc = attendanceDocs
                .cast<QueryDocumentSnapshot?>()
                .firstWhere((doc) => doc?.id == dateStr, orElse: () => null);

            return _buildAttendanceRow(studentUid, date, attendanceDoc);
          }).toList(),
        );
      },
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDisplayDate(date),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusChip(
                      status,
                      isRealTime: _attendanceSubscription != null,
                    ),
                    if (timingStatus != null && status == 'present') ...[
                      const SizedBox(height: 4),
                      _buildTimingBadge(timingStatus),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (clockInAt != null)
                  Text(
                    'In: ${_formatTime(clockInAt.toDate())}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (clockOutAt != null)
                  Text(
                    'Out: ${_formatTime(clockOutAt.toDate())}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (lateReason != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason: $lateReason',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                      if (data['lateReasonEditedBy'] != null)
                        Text(
                          'Edited by: ${data['lateReasonEditedByName'] ?? 'Admin'}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.purple,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check, color: Colors.green, size: 20),
                      onPressed: () => _markPresent(studentUid, dateStr),
                      tooltip: 'Mark Present',
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: () => _markAbsent(studentUid, dateStr),
                      tooltip: 'Mark Absent',
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue, size: 20),
                      onPressed: () =>
                          _editLateReason(studentUid, dateStr, lateReason),
                      tooltip: 'Edit Reason',
                    ),
                    if (data['inLoc'] != null ||
                        data['outLoc'] != null ||
                        data['clockInLoc'] != null ||
                        data['clockOutLoc'] != null)
                      IconButton(
                        icon: Icon(Icons.map, color: Colors.purple, size: 20),
                        onPressed: () => _showLocationMap(data),
                        tooltip: 'View Location',
                      ),
                  ],
                ),
              ],
            ),
          ),
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
        '✅ Student marked as present for $dateStr and notified',
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
        '✅ Student marked as absent for $dateStr and notified',
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Colors.red),
            SizedBox(width: 8),
            Text('Attendance Location Details'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (clockInLoc != null) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.login, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Clock In Location:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('📍 Coordinates:'),
                        Text(
                          '   Latitude: ${clockInLoc.latitude.toStringAsFixed(6)}',
                        ),
                        Text(
                          '   Longitude: ${clockInLoc.longitude.toStringAsFixed(6)}',
                        ),
                        if (clockInTime != null) ...[
                          SizedBox(height: 4),
                          Text('🕐 Time: ${_formatTimestamp(clockInTime)}'),
                        ],
                        if (lateReason != null && lateReason.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text('📝 Late Reason: $lateReason'),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                if (clockOutLoc != null) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.logout, color: Colors.orange, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Clock Out Location:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('📍 Coordinates:'),
                        Text(
                          '   Latitude: ${clockOutLoc.latitude.toStringAsFixed(6)}',
                        ),
                        Text(
                          '   Longitude: ${clockOutLoc.longitude.toStringAsFixed(6)}',
                        ),
                        if (clockOutTime != null) ...[
                          SizedBox(height: 4),
                          Text('🕐 Time: ${_formatTimestamp(clockOutTime)}'),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                if (clockInLoc == null && clockOutLoc == null) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    width: double.infinity,
                    child: Column(
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
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (clockInLoc != null || clockOutLoc != null)
            TextButton.icon(
              onPressed: () {
                final coords = clockInLoc ?? clockOutLoc!;
                _showSuccessSnackBar(
                  'Coordinates: ${coords.latitude.toStringAsFixed(6)}, ${coords.longitude.toStringAsFixed(6)}',
                );
              },
              icon: Icon(Icons.copy),
              label: Text('Copy Coords'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
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
