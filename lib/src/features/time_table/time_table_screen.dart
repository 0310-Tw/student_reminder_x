import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TimetableScreen extends StatelessWidget {
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "will hold":
        return Colors.green;
      case "cancelled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Courses"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(onPressed: () {}, icon: Icon(Icons.search)),
            IconButton(onPressed: () {}, icon: Icon(Icons.notifications)),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: "List View"),
              Tab(text: "Timetable"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("timetable")
              .doc(userId)
              .collection("schedule")
              .orderBy("day")
              .orderBy("time")
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return Center(child: Text("No courses added yet."));
            }

            // Parse Firestore data into a list of course maps
            final courses = docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                "day": data["day"] ?? "",
                "time": data["time"] ?? "",
                "title": data["title"] ?? "",
                "prof": data["prof"] ?? "",
                "location": data["location"] ?? "",
                "status": data["status"] ?? "",
              };
            }).toList();

            // Get unique days and time slots
            final daysSet = courses.map((c) => c["day"] as String).toSet();
            final List<String> days = daysSet.toList();
            days.sort(); // optional: sort alphabetically or by weekday order

            final timeSlotsSet = courses.map((c) => c["time"] as String).toSet();
            final List<String> timeSlots = timeSlotsSet.toList()..sort();

            // Group courses by day for List View
            Map<String, List<Map<String, dynamic>>> coursesByDay = {};
            for (var course in courses) {
              coursesByDay.putIfAbsent(course["day"] as String, () => []).add(course);
            }

            // Create timetable map
            Map<String, Map<String, Map<String, dynamic>?>> timetable = {};
            for (var day in days) {
              timetable[day] = {};
              for (var time in timeSlots) {
                timetable[day]![time] = null;
              }
            }
            for (var course in courses) {
              timetable[course["day"]!]?[course["time"]!] = course;
            }

            return TabBarView(
              children: [
                // ---------------- List View ----------------
                ListView(
                  children: coursesByDay.entries.map((entry) {
                    return ExpansionTile(
                      title: Text(entry.key, style: TextStyle(fontWeight: FontWeight.bold)),
                      children: entry.value.map((course) {
                        final statusColor = getStatusColor(course["status"] ?? "");
                        return ListTile(
                          title: Text("${course["time"]} - ${course["title"]}",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(course["prof"] ?? ""),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text(course["location"] ?? "", style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          trailing: Text(
                            course["status"] ?? "",
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(course["title"] ?? ""),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Instructor: ${course["prof"] ?? ""}"),
                                    Text("Location: ${course["location"] ?? ""}"),
                                    Text("Status: ${course["status"] ?? ""}"),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text("Close"),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),

                // ---------------- Mini Timetable ----------------
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    border: TableBorder.all(color: Colors.grey),
                    defaultColumnWidth: FixedColumnWidth(140),
                    children: [
                      // Header row: Days
                      TableRow(
                        children: [
                          TableCell(child: Container()), // top-left empty cell
                          ...days.map((day) => TableCell(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(day, style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              )),
                        ],
                      ),
                      // Rows for each time slot
                      ...timeSlots.map((time) {
                        return TableRow(
                          children: [
                            TableCell(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(time, style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                            ...days.map((day) {
                              final course = timetable[day]?[time];
                              final statusColor = getStatusColor(course?["status"] ?? "");
                              return TableCell(
                                child: GestureDetector(
                                  onTap: course != null
                                      ? () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: Text(course["title"] ?? ""),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Instructor: ${course["prof"] ?? ""}"),
                                                  Text("Location: ${course["location"] ?? ""}"),
                                                  Text("Status: ${course["status"] ?? ""}"),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: Text("Close"),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      : null,
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    color: course != null ? statusColor.withOpacity(0.3) : Colors.transparent,
                                    child: course != null
                                        ? Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(course["title"] ?? "",
                                                  style: TextStyle(fontWeight: FontWeight.bold)),
                                              Text(course["prof"] ?? "", style: TextStyle(fontSize: 12)),
                                              Text(course["location"] ?? "", style: TextStyle(fontSize: 12)),
                                            ],
                                          )
                                        : SizedBox(),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // TODO: add new course dialog
          },
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}
