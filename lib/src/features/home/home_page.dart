import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/user_service.dart';

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

  @override
  void initState() {
    super.initState();
    _setupLiveCounts();
    _listenAllStudents();
  }

  void _setupLiveCounts() {
    _listenAndUpdate("Mobile", UserService.instance.watchUserByCourseGroup('mobile'));
    _listenAndUpdate("Web", UserService.instance.watchUserByCourseGroup('web'));
    _listenAndUpdate("Tasks", UserService.instance.watchStudentsWithPendingTasks());
    _listenAndUpdate("Reports", UserService.instance.watchStudentsWithReports());
    _listenAndUpdate("Announcements", UserService.instance.watchStudentsWithUnreadAnnouncements());
    _listenAndUpdate("Calendar", UserService.instance.watchStudentsWithUpcomingEvents());
  }

  void _listenAndUpdate(String label, Stream<QuerySnapshot<Map<String, dynamic>>> stream) {
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
            return events.any((e) => (e['date'] as Timestamp).toDate().isAfter(now));
          }).length;
          break;
      }
      setState(() => _counts[label] = count);
    });
  }

  void _listenAllStudents() {
    UserService.instance.watchAllStudents().listen((snap) {
      int present = 0, late = 0, absent = 0;
      for (var doc in snap.docs) {
        final data = doc.data();
        final status = data['attendanceStatus'] ?? 'present';
        switch (status) {
          case 'present':
            present++;
            break;
          case 'late':
            late++;
            break;
          case 'absent':
            absent++;
            break;
        }
      }
      setState(() {
        _totalPresent = present;
        _totalLate = late;
        _totalAbsent = absent;
      });
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
          bottom: const TabBar(
            tabs: [
              Tab(text: "Students"),
              Tab(text: "Documents"),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttendanceSummary(
                    "Present",
                    _totalPresent,
                    Colors.green,
                    onTap: () {
                      setState(() {
                        _selectedAttendanceStatus =
                            _selectedAttendanceStatus == 'present' ? null : 'present';
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
                            _selectedAttendanceStatus == 'late' ? null : 'late';
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
                            _selectedAttendanceStatus == 'absent' ? null : 'absent';
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
                      title: 'Present',
                      radius: 50,
                      titleStyle:
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      value: _totalLate.toDouble(),
                      color: Colors.orange,
                      title: 'Late',
                      radius: 50,
                      titleStyle:
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      value: _totalAbsent.toDouble(),
                      color: Colors.red,
                      title: 'Absent',
                      radius: 50,
                      titleStyle:
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildStudentsTab(),
                  _buildDocumentsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSummary(String label, int count, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
                      _studentStream = UserService.instance.watchUserByCourseGroup('mobile');
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
                      _studentStream = UserService.instance.watchUserByCourseGroup('web');
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
                      _studentStream = UserService.instance.watchStudentsWithUpcomingEvents();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_selectedAction == "Calendar")
            _buildCalendarTab()
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
        if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));

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
              'studentName': "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim(),
              'color': eventColor,
            });
          }
        }

        return TableCalendar<Map<String, dynamic>>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: DateTime.now(),
          eventLoader: (day) => events[day] ?? [],
          calendarBuilders: CalendarBuilders<Map<String, dynamic>>(
            markerBuilder: (context, date, dayEvents) {
              if (dayEvents.isEmpty) return const SizedBox();
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: dayEvents
                    .map<Widget>((e) => Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: e['color'],
                          ),
                        ))
                    .toList(),
              );
            },
          ),
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
        if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));

        List docs = snap.data?.docs ?? [];

        docs = docs.where((d) {
          final data = d.data();
          if (_selectedAttendanceStatus != null) {
            return (data['attendanceStatus'] ?? 'present') == _selectedAttendanceStatus;
          }
          return true;
        }).toList();

        if (docs.isEmpty) return const Text("No students found");

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final data = docs[i].data();
            final name = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
            return ListTile(
              title: Text(name),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(name),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Present: ${data['presentCount'] ?? 0}"),
                        Text("Late: ${data['lateCount'] ?? 0}"),
                        Text("Absent: ${data['absentCount'] ?? 0}"),
                        Text("Location: ${data['location'] ?? 'Unknown'}"),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close"),
                      ),
                    ],
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
    final docStream = FirebaseFirestore.instance.collection('documents').snapshots();
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: filterColors.keys.map((type) {
                  final isSelected = selectedFilter == type;
                  final color = filterColors[type]!;
                  return GestureDetector(
                    onTap: () => setState(() => selectedFilter = type),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? color : color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color, width: 1.5),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? Colors.white : color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: docStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

                  List docs = snapshot.data?.docs ?? [];

                  if (selectedFilter != 'All') {
                    docs = docs.where((d) {
                      final type = (d.data()['type'] ?? 'general').toString().toLowerCase();
                      return type == selectedFilter.toLowerCase();
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("No documents found"),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final title = data['title'] ?? 'Untitled';
                      final uploadedBy = data['uploadedBy'] ?? 'Unknown';
                      final timestamp = data['date'] as Timestamp?;
                      final date = timestamp != null
                          ? "${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}"
                          : 'Unknown date';
                      final type = data['type'] ?? 'general';
                      final badgeColor = getBadgeColor(type);

                      return ListTile(
                        leading: CircleAvatar(radius: 10, backgroundColor: badgeColor),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Uploaded by: $uploadedBy\nDate: $date"),
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
    required VoidCallback onTap,
  }) {
    final bool isSelected = _selectedAction == label;
    final count = _counts[label] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 130,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(60),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.red,
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
