import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// -----------------------
/// TIMETABLE SERVICE
/// -----------------------
class TimetableService {
  final String userId;
  final CollectionReference scheduleRef;

  // Subject → color mapping
  final Map<String, Color> subjectColors = {
    "Math": Colors.blue.shade200,
    "English": Colors.green.shade200,
    "Science": Colors.orange.shade200,
    "History": Colors.red.shade200,
    "Computer": Colors.purple.shade200,
    "Geography": Colors.teal.shade200,
    "PE": Colors.yellow.shade200,
    "Art": Colors.pink.shade200,
  };

  TimetableService({required this.userId})
      : scheduleRef = FirebaseFirestore.instance
            .collection("timetable")
            .doc(userId)
            .collection("schedule");

  // Fetch timetable as day → {time → subject}
  Stream<Map<String, Map<String, String>>> getTimetable() {
    return scheduleRef.snapshots().map((snapshot) {
      Map<String, Map<String, String>> data = {};
      for (var doc in snapshot.docs) {
        String day = doc["day"];
        String time = doc["time"];
        String subject = doc["subject"];
        data[day] ??= {};
        data[day]![time] = subject;
      }
      return data;
    });
  }

  // Update a specific timetable slot
  Future<void> updateSubject(
      {required String day,
      required String time,
      required String subject}) async {
    var snapshot = await scheduleRef
        .where("day", isEqualTo: day)
        .where("time", isEqualTo: time)
        .get();

    if (snapshot.docs.isNotEmpty) {
      // Update existing
      await scheduleRef.doc(snapshot.docs.first.id).update({"subject": subject});
    } else {
      // Create new if missing
      await scheduleRef.add({
        "day": day,
        "time": time,
        "subject": subject,
      });
    }
  }

  // Get color for a subject
  Color getSubjectColor(String subject) {
    return subjectColors[subject] ?? Colors.grey.shade200;
  }
}

/// -----------------------
/// TIMETABLE SCREEN
/// -----------------------
class EditableGridTimetableScreen extends StatelessWidget {
  final List<String> days = ["Mon", "Tue", "Wed", "Thu", "Fri"];
  final List<String> times = ["8-9", "9-10", "10-11", "11-12"];

  final String userId = "demoUser123"; // replace with FirebaseAuth.instance.currentUser!.uid
  late final TimetableService timetableService;

  EditableGridTimetableScreen({super.key}) {
    timetableService = TimetableService(userId: userId);
  }

  void showEditDialog(
      BuildContext context, String day, String time, String? currentSubject) {
    final controller = TextEditingController(text: currentSubject ?? "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit $day $time"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: "Subject",
            hintText: "Enter subject name",
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await timetableService.updateSubject(
                  day: day,
                  time: time,
                  subject: controller.text.trim(),
                );
              }
              Navigator.pop(ctx);
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Editable Timetable"),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<Map<String, Map<String, String>>>(
        stream: timetableService.getTimetable(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final timetable = snapshot.data!;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: Colors.grey),
              defaultColumnWidth: FixedColumnWidth(100),
              children: [
                // Header row (days)
                TableRow(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      color: Colors.deepPurple.shade100,
                      child: Text("Time",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    ...days.map((day) => Container(
                          padding: EdgeInsets.all(8),
                          color: Colors.deepPurple.shade100,
                          child: Text(
                            day,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        )),
                  ],
                ),
                // Time rows
                ...times.map((time) {
                  return TableRow(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        color: Colors.grey.shade200,
                        child: Text(
                          time,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      ...days.map((day) {
                        String? subject = timetable[day]?[time];
                        Color bgColor = subject != null
                            ? timetableService.getSubjectColor(subject)
                            : Colors.white;

                        return GestureDetector(
                          onTap: () => showEditDialog(context, day, time, subject),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            alignment: Alignment.center,
                            color: bgColor,
                            child: Text(
                              subject ?? "-",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: subject != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}