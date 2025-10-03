import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/user_service.dart';
import 'package:students_reminder/src/widgets/atrisk_banner_notifications.dart';
import 'package:students_reminder/src/widgets/suspension_check.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:students_reminder/src/shared/routes.dart';
import 'package:students_reminder/src/features/profile/student_profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedAction;
  String? _selectedAttendanceStatus;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _studentStream;
  final uid = AuthService.instance.currentUser?.uid;

  // Cache for student attendance status to avoid repeated queries
  final Map<String, String> _studentAttendanceCache = {};

  final Map<String, int> _counts = {
    "Mobile": 0,
    "Web": 0,
    "Tasks": 0,
    "Reports": 0,
    "Announcements": 0,
    "Calendar": 0,
  };

  int _totalPresent = 0;
  int _totalLate = 0;
  int _totalAbsent = 0;

  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _setupLiveCounts();
    _listenAllStudents();
    // Clear cache daily
    _setupDailyCacheClear();
  }

  void _setupDailyCacheClear() {
    // Clear attendance cache at midnight to ensure fresh data each day
    Timer.periodic(const Duration(hours: 1), (timer) {
      final now = DateTime.now();
      if (now.hour == 0 && now.minute == 0) {
        _studentAttendanceCache.clear();
      }
    });
  }

  void _setupLiveCounts() {
    _listenAndUpdate(
      "Mobile",
      UserService.instance.watchUserByCourseGroup('mobile'),
    );
    _listenAndUpdate("Web", UserService.instance.watchUserByCourseGroup('web'));
    _listenAndUpdate(
      "Tasks",
      UserService.instance.watchStudentsWithPendingTasks(),
    );
    _listenAndUpdate(
      "Reports",
      UserService.instance.watchStudentsWithReports(),
    );
    _listenAndUpdate(
      "Announcements",
      UserService.instance.watchStudentsWithUnreadAnnouncements(),
    );
    _listenAndUpdate(
      "Calendar",
      UserService.instance.watchStudentsWithUpcomingEvents(),
    );
  }

  void _listenAndUpdate(
    String label,
    Stream<QuerySnapshot<Map<String, dynamic>>> stream,
  ) {
    stream.listen((snap) {
      int count = 0;
      switch (label) {
        case "Mobile":
          count = snap.docs.where((d) => d['courseGroup'] == 'mobile').length;
          break;
        case "Web":
          count = snap.docs.where((d) => d['courseGroup'] == 'web').length;
          break;
        case "Tasks":
          count = snap.docs.where((d) {
            final tasks = List.from(d['tasks'] ?? []);
            return tasks.any((t) => t['completed'] == false);
          }).length;
          break;
        case "Reports":
          count = snap.docs.where((d) {
            final reports = List.from(d['reports'] ?? []);
            return reports.isNotEmpty;
          }).length;
          break;
        case "Announcements":
          count = snap.docs.where((d) {
            final ann = List.from(d['announcements'] ?? []);
            return ann.any((a) => a['read'] == false);
          }).length;
          break;
        case "Calendar":
          final now = DateTime.now();
          count = snap.docs.where((d) {
            final events = List.from(d['events'] ?? []);
            return events.any(
              (e) => (e['date'] as Timestamp).toDate().isAfter(now),
            );
          }).length;
          break;
      }
      setState(() => _counts[label] = count);
    });
  }

  void _listenAllStudents() {
    UserService.instance.watchAllStudents().listen((snap) async {
      int present = 0, late = 0, absent = 0;

      // Get today's date in the format used by attendance system
      final now = DateTime.now();
      final todayId =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      for (var doc in snap.docs) {
        final data = doc.data();
        final uid = data['uid'] ?? doc.id;

        try {
          // Get today's attendance for this student
          final attendanceDoc = await FirebaseFirestore.instance
              .collection('attendance')
              .doc(uid)
              .collection('days')
              .doc(todayId)
              .get();

          if (attendanceDoc.exists) {
            final attendanceData = attendanceDoc.data()!;
            final clockedIn = attendanceData['inAt'] != null;

            if (!clockedIn) {
              // No clock-in means absent
              absent++;
            } else {
              // Use the stored status from clock-in
              final rawStatus = (attendanceData['status'] ?? 'present')
                  .toString()
                  .toLowerCase();
              if (rawStatus.contains('late')) {
                late++;
              } else {
                present++;
              }
            }
          } else {
            // No attendance record means absent
            absent++;
          }
        } catch (e) {
          // If there's an error, default to absent
          absent++;
        }
      }

      if (mounted) {
        setState(() {
          _totalPresent = present;
          _totalLate = late;
          _totalAbsent = absent;
        });
      }
    });
  }

  Future<String> _getStudentAttendanceStatus(String studentUid) async {
    // Check cache first
    if (_studentAttendanceCache.containsKey(studentUid)) {
      return _studentAttendanceCache[studentUid]!;
    }

    try {
      // Get today's date in the format used by attendance system
      final now = DateTime.now();
      final todayId =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Get today's attendance for this student
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(studentUid)
          .collection('days')
          .doc(todayId)
          .get();

      String status = 'absent'; // Default to absent

      if (attendanceDoc.exists) {
        final attendanceData = attendanceDoc.data()!;
        final clockedIn = attendanceData['inAt'] != null;

        if (clockedIn) {
          // Use the stored status from clock-in
          final rawStatus = (attendanceData['status'] ?? 'present')
              .toString()
              .toLowerCase();
          if (rawStatus.contains('late')) {
            status = 'late';
          } else {
            status = 'present';
          }
        }
      }

      // Cache the result
      _studentAttendanceCache[studentUid] = status;
      return status;
    } catch (e) {
      // If there's an error, default to absent
      _studentAttendanceCache[studentUid] = 'absent';
      return 'absent';
    }
  }

  Future<List> _filterStudentsByAttendance(
    List docs,
    String targetStatus,
  ) async {
    final filteredDocs = <dynamic>[];

    for (var doc in docs) {
      final data = doc.data();
      final studentUid = data['uid'] ?? doc.id;
      final status = await _getStudentAttendanceStatus(studentUid);

      if (status == targetStatus) {
        filteredDocs.add(doc);
      }
    }

    return filteredDocs;
  }

  Future<void> _showStudentAttendanceForDate(DateTime selectedDay) async {
    try {
      // Get the current user's uid
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return;

      final studentUid = currentUser.uid;

      // Format the date for attendance lookup
      final dateId =
          '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';

      // Get attendance data for this date
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(studentUid)
          .collection('days')
          .doc(dateId)
          .get();

      String status = 'Absent';
      String clockInTime = 'Not clocked in';
      String clockOutTime = 'Not clocked out';
      Color statusColor = Colors.red;

      if (attendanceDoc.exists) {
        final attendanceData = attendanceDoc.data()!;

        // Get clock in time
        if (attendanceData['inAt'] != null) {
          final clockInTimestamp = attendanceData['inAt'] as Timestamp;
          final clockInDateTime = clockInTimestamp.toDate();
          clockInTime =
              '${clockInDateTime.hour.toString().padLeft(2, '0')}:${clockInDateTime.minute.toString().padLeft(2, '0')}';

          // Get status from stored data
          final rawStatus = (attendanceData['status'] ?? 'present')
              .toString()
              .toLowerCase();
          if (rawStatus.contains('late')) {
            status = 'Late';
            statusColor = Colors.orange;
          } else {
            status = 'Present';
            statusColor = Colors.green;
          }
        }

        // Get clock out time if exists
        if (attendanceData['outAt'] != null) {
          final clockOutTimestamp = attendanceData['outAt'] as Timestamp;
          final clockOutDateTime = clockOutTimestamp.toDate();
          clockOutTime =
              '${clockOutDateTime.hour.toString().padLeft(2, '0')}:${clockOutDateTime.minute.toString().padLeft(2, '0')}';
        }
      }

      // Show the attendance dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Attendance - ${selectedDay.day}/${selectedDay.month}/${selectedDay.year}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Status: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.login, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Clock In: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(clockInTime),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.logout, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text(
                      'Clock Out: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(clockOutTime),
                  ],
                ),
                if (status == 'Late') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Arrived after 10:00 AM',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
    } catch (e) {
      // Handle error - show simple error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: const Text(
              'Unable to load attendance data for this date.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> toggleTaskCompletion(
    String uid,
    Map<String, dynamic> task,
  ) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final updatedTask = {...task, 'completed': !(task['completed'] ?? false)};
    await ref.update({
      'tasks': FieldValue.arrayRemove([task]),
    });
    await ref.update({
      'tasks': FieldValue.arrayUnion([updatedTask]),
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Dashboard"),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRoutes.profile);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Students"),
              Tab(text: "Documents"),
            ],
          ),
        ),
        body: SuspensionCheck(
          child: Column(
            children: [
              AtRiskBannerNotifications(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttendanceSummary(
                      "Early",
                      _totalPresent,
                      Colors.green,
                      onTap: () {
                        setState(() {
                          _selectedAttendanceStatus =
                              _selectedAttendanceStatus == 'present'
                              ? null
                              : 'present';
                        });
                      },
                    ),
                    _buildAttendanceSummary(
                      "Late",
                      _totalLate,
                      Colors.orange,
                      onTap: () {
                        setState(() {
                          _selectedAttendanceStatus =
                              _selectedAttendanceStatus == 'late'
                              ? null
                              : 'late';
                        });
                      },
                    ),
                    _buildAttendanceSummary(
                      "Absent",
                      _totalAbsent,
                      Colors.red,
                      onTap: () {
                        setState(() {
                          _selectedAttendanceStatus =
                              _selectedAttendanceStatus == 'absent'
                              ? null
                              : 'absent';
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 160,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        value: _totalPresent.toDouble(),
                        color: Colors.green,
                        title: 'Early',
                        radius: 50,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      PieChartSectionData(
                        value: _totalLate.toDouble(),
                        color: Colors.orange,
                        title: 'Late',
                        radius: 50,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      PieChartSectionData(
                        value: _totalAbsent.toDouble(),
                        color: Colors.red,
                        title: 'Absent',
                        radius: 50,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [_buildStudentsTab(), _buildDocumentsTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceSummary(
    String label,
    int count,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionContainer(
                  icon: Icons.phone_android,
                  label: "Mobile",
                  color: Colors.green,
                  onTap: () {
                    setState(() {
                      _selectedAction = "Mobile";
                      _selectedAttendanceStatus = null;
                      _studentStream = UserService.instance
                          .watchUserByCourseGroup('mobile');
                    });
                  },
                ),
                _buildActionContainer(
                  icon: Icons.web,
                  label: "Web",
                  color: Colors.orange,
                  onTap: () {
                    setState(() {
                      _selectedAction = "Web";
                      _selectedAttendanceStatus = null;
                      _studentStream = UserService.instance
                          .watchUserByCourseGroup('web');
                    });
                  },
                ),
                _buildActionContainer(
                  icon: Icons.event,
                  label: "Calendar",
                  color: Colors.teal,
                  onTap: () {
                    setState(() {
                      _selectedAction = "Calendar";
                      _studentStream = UserService.instance
                          .watchStudentsWithUpcomingEvents();
                      _selectedDate = null;
                    });
                  },
                ),
                _buildActionContainer(
                  icon: Icons.task,
                  label: "Tasks",
                  color: Colors.purple,
                  onTap: () {
                    setState(() {
                      _selectedAction = "Tasks";
                      _studentStream = UserService.instance
                          .watchStudentsWithPendingTasks();
                      _selectedAttendanceStatus = null;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_selectedAction == "Calendar")
            _buildCalendarTab()
          else if (_selectedAction == "Tasks")
            _buildTasksTab()
          else
            _buildStudentsList(),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _studentStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          // Handle permission errors during logout gracefully
          if (snap.error.toString().contains('permission-denied')) {
            return Center(child: Text("Please log in to view data"));
          }
          return Center(child: Text("Error: ${snap.error}"));
        }

        final events = <DateTime, List<Map<String, dynamic>>>{};

        for (var doc in snap.data?.docs ?? []) {
          final data = doc.data();
          final studentEvents = List.from(data['events'] ?? []);
          final status = data['attendanceStatus'] ?? 'present';
          Color eventColor;
          switch (status) {
            case 'present':
              eventColor = Colors.green;
              break;
            case 'late':
              eventColor = Colors.orange;
              break;
            case 'absent':
              eventColor = Colors.red;
              break;
            default:
              eventColor = Colors.blue;
          }
          for (var e in studentEvents) {
            final date = (e['date'] as Timestamp).toDate();
            final day = DateTime(date.year, date.month, date.day);
            events[day] ??= [];
            events[day]!.add({
              ...e,
              'studentName':
                  "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim(),
              'color': eventColor,
              'attendanceStatus': status,
            });
          }
        }

        return Column(
          children: [
            TableCalendar<Map<String, dynamic>>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _selectedDate ?? DateTime.now(),
              selectedDayPredicate: (day) =>
                  _selectedDate != null &&
                  day.year == _selectedDate!.year &&
                  day.month == _selectedDate!.month &&
                  day.day == _selectedDate!.day,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDate = selectedDay;
                });
                _showStudentAttendanceForDate(selectedDay);
              },
              eventLoader: (day) => events[day] ?? [],
              calendarBuilders: CalendarBuilders<Map<String, dynamic>>(
                markerBuilder: (context, date, dayEvents) {
                  if (dayEvents.isEmpty) return const SizedBox();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: dayEvents
                        .map<Widget>(
                          (e) => Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: e['color'],
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTasksTab() {
    if (_studentStream == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _studentStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snap.hasError) {
          // Handle permission errors during logout gracefully
          if (snap.error.toString().contains('permission-denied')) {
            return Center(child: Text("Please log in to view data"));
          }
          return Center(child: Text("Error: ${snap.error}"));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const Text("No tasks found");

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final studentName =
                "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
            final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);

            if (tasks.isEmpty) return const SizedBox();

            return ExpansionTile(
              title: Text(
                studentName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              children: tasks.map((task) {
                final isCompleted = task['completed'] ?? false;
                final dueDate = (task['dueDate'] as Timestamp?)?.toDate();
                final overdue =
                    dueDate != null &&
                    dueDate.isBefore(DateTime.now()) &&
                    !isCompleted;
                return ListTile(
                  leading: Checkbox(
                    value: isCompleted,
                    onChanged: (_) {
                      toggleTaskCompletion(data['uid'] ?? '', task);
                    },
                  ),
                  title: Text(task['title'] ?? 'Untitled'),
                  subtitle: dueDate != null
                      ? Text(
                          "Due: ${dueDate.day}/${dueDate.month}/${dueDate.year}",
                        )
                      : null,
                  trailing: overdue
                      ? const Icon(Icons.error, color: Colors.red)
                      : null,
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentsList() {
    if (_studentStream == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _studentStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          // Handle permission errors during logout gracefully
          if (snap.error.toString().contains('permission-denied')) {
            return Center(child: Text("Please log in to view data"));
          }
          return Center(child: Text("Error: ${snap.error}"));
        }

        List docs = snap.data?.docs ?? [];

        // If attendance status filter is selected, filter by actual attendance data
        if (_selectedAttendanceStatus != null) {
          return FutureBuilder<List>(
            future: _filterStudentsByAttendance(
              docs,
              _selectedAttendanceStatus!,
            ),
            builder: (context, filteredSnapshot) {
              if (filteredSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final filteredDocs = filteredSnapshot.data ?? [];

              if (filteredDocs.isEmpty) return const Text("No students found");

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredDocs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final doc = filteredDocs[i];
                  final data = doc.data();
                  final uid = doc.id; // Use document ID as UID
                  final name =
                      "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}"
                          .trim();
                  return ListTile(
                    title: Text(name),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentProfilePage(uid: uid),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        }

        // No attendance filter, show all students
        if (docs.isEmpty) return const Text("No students found");

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data();
            final uid = doc.id; // Use document ID as UID
            final name = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}"
                .trim();
            return ListTile(
              title: Text(name),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentProfilePage(uid: uid),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDocumentsTab() {
    final docStream = FirebaseFirestore.instance
        .collection('documents')
        .snapshots();
    String selectedFilter = 'All';

    return StatefulBuilder(
      builder: (context, setState) {
        Map<String, Color> filterColors = {
          'All': Colors.grey,
          'General': Colors.green,
          'Info': Colors.blue,
          'Important': Colors.orange,
          'Urgent': Colors.red,
        };

        Color getBadgeColor(String type) {
          switch (type.toLowerCase()) {
            case 'urgent':
              return Colors.red;
            case 'important':
              return Colors.orange;
            case 'info':
              return Colors.blue;
            case 'general':
            default:
              return Colors.green;
          }
        }

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filterColors.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: ChoiceChip(
                      label: Text(e.key),
                      selectedColor: e.value,
                      selected: selectedFilter == e.key,
                      onSelected: (selected) {
                        setState(() {
                          selectedFilter = e.key;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: docStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    // Handle permission errors during logout gracefully
                    if (snap.error.toString().contains('permission-denied')) {
                      return Center(child: Text("Please log in to view data"));
                    }
                    return Center(child: Text("Error: ${snap.error}"));
                  }
                  final docs = snap.data?.docs ?? [];
                  final filteredDocs = selectedFilter == 'All'
                      ? docs
                      : docs
                            .where(
                              (d) =>
                                  (d.data()['type'] ?? '')
                                      .toString()
                                      .toLowerCase() ==
                                  selectedFilter.toLowerCase(),
                            )
                            .toList();
                  if (filteredDocs.isEmpty)
                    return const Text("No documents found");

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDocs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final data = filteredDocs[index].data();
                      final type = data['type'] ?? 'General';
                      final color = getBadgeColor(type);
                      return ListTile(
                        title: Text(data['title'] ?? 'Untitled'),
                        subtitle: Text(type),
                        trailing: Icon(Icons.description, color: color),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionContainer({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              Text(
                (_counts[label] ?? 0).toString(),
                style: TextStyle(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
