import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/user_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedAction;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _studentStream;
  final uid = AuthService.instance.currentUser?.uid;

  // Attendance filter for interactive chart
  String? _selectedAttendanceStatus; // 'present', 'late', 'absent'

  // Student dashboard counts
  final Map<String, int> _counts = {
    "Mobile": 0,
    "Web": 0,
    "Tasks": 0,
    "Reports": 0,
    "Announcements": 0,
    "Calendar": 0,
  };

  // Documents dashboard state
  String? _selectedDocCategory;
  final Map<String, int> _docCounts = {
    'All': 0,
    'PDFs': 0,
    'Docs': 0,
    'Images': 0,
  };

  @override
  void initState() {
    super.initState();
    _setupLiveCounts();
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
            return events.any((e) {
              final date = (e['date'] as Timestamp).toDate();
              return date.isAfter(now);
            });
          }).length;
          break;
      }

      setState(() {
        _counts[label] = count;
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
        body: TabBarView(
          children: [
            // ----------- Student Dashboard Tab -----------
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _quickAction("Mobile", icon: Icons.phone_android),
                        const SizedBox(width: 16),
                        _quickAction("Web", icon: Icons.web),
                        const SizedBox(width: 16),
                        _quickAction("Tasks", icon: Icons.task_alt),
                        const SizedBox(width: 16),
                        _quickAction("Reports", icon: Icons.bar_chart),
                        const SizedBox(width: 16),
                        _quickAction("Announcements", icon: Icons.announcement),
                        const SizedBox(width: 16),
                        _quickAction("Calendar", icon: Icons.calendar_month),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_studentStream != null)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _studentStream,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));

                        List docs = snap.data?.docs ?? [];

                        // Filter students based on selected action and attendance status
                        docs = docs.where((d) {
                          switch (_selectedAction) {
                            case "Mobile":
                              if (_selectedAttendanceStatus != null) {
                                return d['courseGroup'] == 'mobile' &&
                                    (d['attendanceStatus'] ?? 'present') == _selectedAttendanceStatus;
                              }
                              return d['courseGroup'] == 'mobile';
                            case "Web":
                              if (_selectedAttendanceStatus != null) {
                                return d['courseGroup'] == 'web' &&
                                    (d['attendanceStatus'] ?? 'present') == _selectedAttendanceStatus;
                              }
                              return d['courseGroup'] == 'web';
                            case "Tasks":
                              final tasks = List.from(d['tasks'] ?? []);
                              return tasks.any((t) => t['completed'] == false);
                            case "Reports":
                              final reports = List.from(d['reports'] ?? []);
                              return reports.isNotEmpty;
                            case "Announcements":
                              final ann = List.from(d['announcements'] ?? []);
                              return ann.any((a) => a['read'] == false);
                            case "Calendar":
                              final now = DateTime.now();
                              final events = List.from(d['events'] ?? []);
                              return events.any((e) => (e['date'] as Timestamp).toDate().isAfter(now));
                            default:
                              return false;
                          }
                        }).toList();

                        if (docs.isEmpty) return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("No students found"),
                        );

                        // Grid for Mobile/Web
                        if (_selectedAction == "Mobile" || _selectedAction == "Web") {
                          return Column(
                            children: [
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: docs.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 3 / 2,
                                ),
                                itemBuilder: (context, i) {
                                  final data = docs[i];
                                  final name = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
                                  final course = data['courseGroup'] ?? '';
                                  final isMe = data.id == uid;
                                  return Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: Colors.blue.shade100,
                                            child: Icon(course == 'mobile' ? Icons.phone_android : Icons.web, color: Colors.blue),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                          const SizedBox(height: 4),
                                          Text(course == 'mobile' ? "Mobile App Dev" : "Web App Dev", style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                                          if (isMe)
                                            const Padding(
                                              padding: EdgeInsets.only(top: 4),
                                              child: Text("You", style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 12),

                              // Interactive Attendance Chart
                              SizedBox(
                                height: 160,
                                child: PieChart(
                                  PieChartData(
                                    sections: [
                                      PieChartSectionData(
                                        value: docs.where((d) => d['attendanceStatus'] == 'present').length.toDouble(),
                                        color: Colors.green,
                                        title: 'Present',
                                        radius: _selectedAttendanceStatus == 'present' ? 60 : 50,
                                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      PieChartSectionData(
                                        value: docs.where((d) => d['attendanceStatus'] == 'late').length.toDouble(),
                                        color: Colors.orange,
                                        title: 'Late',
                                        radius: _selectedAttendanceStatus == 'late' ? 60 : 50,
                                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      PieChartSectionData(
                                        value: docs.where((d) => d['attendanceStatus'] == 'absent').length.toDouble(),
                                        color: Colors.red,
                                        title: 'Absent',
                                        radius: _selectedAttendanceStatus == 'absent' ? 60 : 50,
                                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 30,
                                    pieTouchData: PieTouchData(
                                      touchCallback: (event, response) {
                                        if (response == null || response.touchedSection == null) return;
                                        final index = response.touchedSection!.touchedSectionIndex;
                                        setState(() {
                                          _selectedAttendanceStatus = switch (index) {
                                            0 => _selectedAttendanceStatus == 'present' ? null : 'present',
                                            1 => _selectedAttendanceStatus == 'late' ? null : 'late',
                                            2 => _selectedAttendanceStatus == 'absent' ? null : 'absent',
                                            _ => null,
                                          };
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),

                              if (_selectedAttendanceStatus != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    "Showing: ${_selectedAttendanceStatus!.toUpperCase()} students",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          );
                        }

                        // Other lists for Tasks, Reports, etc.
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final data = docs[i];
                            final name = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
                            return ListTile(title: Text(name));
                          },
                        );
                      },
                    ),
                ],
              ),
            ),

            // ----------- Documents Dashboard Tab -----------
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Documents Dashboard",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  // ... your existing documents tab code ...
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(String label, {required IconData icon}) {
    final bool isSelected = _selectedAction == label;
    final count = _counts[label] ?? 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAction = label;
          _selectedAttendanceStatus = null; // reset chart filter

          switch (label) {
            case "Mobile":
              _studentStream = UserService.instance.watchUserByCourseGroup('mobile');
              break;
            case "Web":
              _studentStream = UserService.instance.watchUserByCourseGroup('web');
              break;
            case "Tasks":
              _studentStream = UserService.instance.watchStudentsWithPendingTasks();
              break;
            case "Reports":
              _studentStream = UserService.instance.watchStudentsWithReports();
              break;
            case "Announcements":
              _studentStream = UserService.instance.watchStudentsWithUnreadAnnouncements();
              break;
            case "Calendar":
              _studentStream = UserService.instance.watchStudentsWithUpcomingEvents();
              break;
          }
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.blue : Colors.blue.shade100,
            ),
            child: Column(
              children: [
                Icon(icon, color: isSelected ? Colors.white : Colors.blue, size: 28),
                const SizedBox(height: 8),
                Text(label, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
