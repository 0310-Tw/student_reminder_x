// file: lib/src/admin/pages/attendance_admin_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/attendance_service.dart';

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

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    final isAdmin = await AttendanceService.isCurrentUserAdmin();
    setState(() {
      _isAdmin = isAdmin;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Admin access required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text('You do not have permission to access this page.'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Admin'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildDateRangePicker(),
          Expanded(child: _buildStudentsList()),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date Range',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_formatDisplayDate(_startDate)} - ${_formatDisplayDate(_endDate)}',
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range),
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

        final students = snapshot.data?.docs ?? [];

        if (students.isEmpty) {
          return const Center(child: Text('No students found'));
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
    final status = data['status'] ?? 'not_marked';
    final clockInAt = data['clockInAt'] as Timestamp?;
    final clockOutAt = data['clockOutAt'] as Timestamp?;
    final lateReason = data['lateReason'] as String?;

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
                _buildStatusChip(status),
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
                  Text(
                    'Reason: $lateReason',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
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
                      icon: const Icon(
                        Icons.check,
                        color: Colors.green,
                        size: 20,
                      ),
                      onPressed: () => _markPresent(studentUid, dateStr),
                      tooltip: 'Mark Present',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _markAbsent(studentUid, dateStr),
                      tooltip: 'Mark Absent',
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.blue,
                        size: 20,
                      ),
                      onPressed: () =>
                          _editLateReason(studentUid, dateStr, lateReason),
                      tooltip: 'Edit Reason',
                    ),
                    if (data['clockInLoc'] != null ||
                        data['clockOutLoc'] != null)
                      IconButton(
                        icon: const Icon(
                          Icons.map,
                          color: Colors.purple,
                          size: 20,
                        ),
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

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'present':
        color = Colors.green;
        label = 'Present';
        break;
      case 'late':
        color = Colors.orange;
        label = 'Late';
        break;
      case 'early':
        color = Colors.blue;
        label = 'Early';
        break;
      case 'absent':
        color = Colors.red;
        label = 'Absent';
        break;
      default:
        color = Colors.grey;
        label = 'Not Marked';
    }

    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
    );
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
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
      _showSuccessSnackBar('Student marked as present');
    } catch (e) {
      _showErrorSnackBar('Failed to mark present: $e');
    }
  }

  Future<void> _markAbsent(String studentUid, String dateStr) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Absent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mark this student as absent for $dateStr?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark Absent'),
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
      _showSuccessSnackBar('Student marked as absent');
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
        title: const Text('Edit Late Reason'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Late Reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
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
      _showSuccessSnackBar('Late reason updated');
    } catch (e) {
      _showErrorSnackBar('Failed to update reason: $e');
    }
  }

  Future<void> _showLocationMap(Map<String, dynamic> data) async {
    final clockInLoc = data['clockInLoc'] as GeoPoint?;
    final clockOutLoc = data['clockOutLoc'] as GeoPoint?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attendance Locations'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (clockInLoc != null) ...[
                const Text(
                  'Clock In Location:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Latitude: ${clockInLoc.latitude}'),
                Text('Longitude: ${clockInLoc.longitude}'),
                const SizedBox(height: 16),
              ],
              if (clockOutLoc != null) ...[
                const Text(
                  'Clock Out Location:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Latitude: ${clockOutLoc.latitude}'),
                Text('Longitude: ${clockOutLoc.longitude}'),
                const SizedBox(height: 16),
              ],
              const Text(
                'Note: Install google_maps_flutter package to view locations on map.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
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
        ],
      ),
    );
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<DateTime> _generateDateRange(DateTime start, DateTime end) {
    final dates = <DateTime>[];
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDate)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }

    return dates;
  }

  String _formatDisplayDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateString(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
