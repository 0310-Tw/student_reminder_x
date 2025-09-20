import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class EditableTimetableScreen extends StatefulWidget {
  @override
  _EditableTimetableScreenState createState() =>
      _EditableTimetableScreenState();
}

class _EditableTimetableScreenState extends State<EditableTimetableScreen> {
  List<String> days = [];
  List<String> times = []; // Format: "8-9|1h"

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

  final Map<String, Color> customColors = {};
  final List<String> durationOptions = ["30min", "45min", "1h", "1h 30min", "2h"];

  String userId = "demoUser123"; // replace with FirebaseAuth.instance.currentUser!.uid

  Color getSubjectColor(String subject) {
    if (subjectColors.containsKey(subject)) return subjectColors[subject]!;
    if (!customColors.containsKey(subject)) {
      final random = Random(subject.hashCode);
      customColors[subject] = Color.fromARGB(
        255,
        100 + random.nextInt(156),
        100 + random.nextInt(156),
        100 + random.nextInt(156),
      );
    }
    return customColors[subject]!;
  }

  @override
  void initState() {
    super.initState();
    _loadStructure();
  }

  Future<void> _loadStructure() async {
    final doc = await FirebaseFirestore.instance
        .collection("timetable_structure")
        .doc(userId)
        .get();

    if (doc.exists) {
      setState(() {
        days = List<String>.from(doc.data()?['days'] ?? []);
        times = List<String>.from(doc.data()?['times'] ?? []);
      });
    } else {
      setState(() {
        days = ["Mon", "Tue", "Wed", "Thu", "Fri"];
        times = ["8-9|1h", "9-10|1h", "10-11|1h", "11-12|1h"];
      });
      await FirebaseFirestore.instance
          .collection("timetable_structure")
          .doc(userId)
          .set({"days": days, "times": times});
    }
  }

  Future<void> _updateStructure() async {
    await FirebaseFirestore.instance
        .collection("timetable_structure")
        .doc(userId)
        .set({"days": days, "times": times});
  }

  Stream<Map<String, Map<String, String>>> getUserTimetable(String uid) {
    return FirebaseFirestore.instance
        .collection("timetable")
        .doc(uid)
        .collection("schedule")
        .snapshots()
        .map((snapshot) {
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

  Future<void> updateSubject(
      String uid, String day, String time, String subject) async {
    final scheduleRef = FirebaseFirestore.instance
        .collection("timetable")
        .doc(uid)
        .collection("schedule");

    var snapshot = await scheduleRef
        .where("day", isEqualTo: day)
        .where("time", isEqualTo: time)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await scheduleRef.doc(snapshot.docs.first.id).update({
        "subject": subject,
      });
    } else {
      await scheduleRef.add({
        "day": day,
        "time": time,
        "subject": subject,
      });
    }
  }

  void showEditDialog(
      BuildContext context, String uid, String day, String time, String? currentSubject) {
    final controller = TextEditingController(text: currentSubject ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit $day $time"),
        content: SizedBox(
          width: 300,
          child: Autocomplete<String>(
            initialValue: TextEditingValue(text: currentSubject ?? ""),
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text == '') return const Iterable<String>.empty();
              return subjectColors.keys.where((subject) => subject
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase()));
            },
            displayStringForOption: (option) => option,
            fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
              textController.text = controller.text;
              textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: textController.text.length));
              textController.addListener(() {
                controller.text = textController.text;
              });
              return TextField(
                controller: textController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: "Subject",
                  hintText: "Type or select subject",
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  child: Container(
                    width: 300,
                    color: Colors.white,
                    child: ListView.builder(
                      padding: EdgeInsets.all(4),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return GestureDetector(
                          onTap: () {
                            onSelected(option);
                          },
                          child: Container(
                            padding: EdgeInsets.all(8),
                            color: getSubjectColor(option),
                            child: Text(option),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            onSelected: (selection) {
              controller.text = selection;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await updateSubject(uid, day, time, controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  // ------------------ Day / Time CRUD ------------------

  void addDay() async {
    final controller = TextEditingController();
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text("Add Day"),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(hintText: "Enter day name"),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
                ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        setState(() {
                          days.add(controller.text.trim());
                        });
                        _updateStructure();
                      }
                      Navigator.pop(ctx);
                    },
                    child: Text("Add")),
              ],
            ));
  }

  void addTime() async {
    String? selectedDuration = durationOptions.first;
    final timeController = TextEditingController();

    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text("Add Time Slot"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: timeController,
                    decoration: InputDecoration(hintText: "Enter time (e.g., 12-1)"),
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedDuration,
                    decoration: InputDecoration(labelText: "Duration"),
                    items: durationOptions
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (val) {
                      selectedDuration = val;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
                ElevatedButton(
                    onPressed: () {
                      if (timeController.text.trim().isNotEmpty) {
                        final combined = "${timeController.text.trim()}|$selectedDuration";
                        setState(() {
                          times.add(combined);
                        });
                        _updateStructure();
                      }
                      Navigator.pop(ctx);
                    },
                    child: Text("Add")),
              ],
            ));
  }

  void editTime(int index) async {
    String current = times[index];
    List<String> parts = current.split('|');
    String currentTime = parts[0];
    String currentDuration = parts.length > 1 ? parts[1] : durationOptions.first;

    String? selectedDuration = currentDuration;
    final timeController = TextEditingController(text: currentTime);

    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text("Edit Time Slot"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: timeController,
                    decoration: InputDecoration(hintText: "Enter time (e.g., 12-1)"),
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedDuration,
                    decoration: InputDecoration(labelText: "Duration"),
                    items: durationOptions
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (val) {
                      selectedDuration = val;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
                ElevatedButton(
                    onPressed: () {
                      final combined = "${timeController.text.trim()}|$selectedDuration";
                      setState(() {
                        times[index] = combined;
                      });
                      _updateStructure();
                      Navigator.pop(ctx);
                    },
                    child: Text("Save")),
              ],
            ));
  }

  void deleteTime(int index) {
    String deleted = times[index];
    setState(() {
      times.removeAt(index);
    });
    _updateStructure();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Deleted time '$deleted'"),
      action: SnackBarAction(
        label: "Undo",
        onPressed: () {
          setState(() {
            times.insert(index, deleted);
          });
          _updateStructure();
        },
      ),
    ));
  }

  void editDay(int index) async {
    final controller = TextEditingController(text: days[index]);
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text("Edit Day"),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(hintText: "Enter new name"),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
                ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        setState(() {
                          days[index] = controller.text.trim();
                        });
                        _updateStructure();
                      }
                      Navigator.pop(ctx);
                    },
                    child: Text("Save")),
              ],
            ));
  }

  void deleteDay(int index) {
    String deleted = days[index];
    setState(() {
      days.removeAt(index);
    });
    _updateStructure();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Deleted day '$deleted'"),
      action: SnackBarAction(
        label: "Undo",
        onPressed: () {
          setState(() {
            days.insert(index, deleted);
          });
          _updateStructure();
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Editable Timetable"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(icon: Icon(Icons.add_box), tooltip: "Add Day", onPressed: addDay),
          IconButton(icon: Icon(Icons.add_chart), tooltip: "Add Time Slot", onPressed: addTime),
        ],
      ),
      body: StreamBuilder<Map<String, Map<String, String>>>(
        stream: getUserTimetable(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final timetable = snapshot.data!;
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  border: TableBorder.all(color: Colors.grey),
                  defaultColumnWidth: FixedColumnWidth(120),
                  children: [
                    // Header Row
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          color: Colors.deepPurple.shade100,
                          child: Text("Time / Duration",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        ...days.asMap().entries.map((entry) {
                          int i = entry.key;
                          String day = entry.value;
                          return GestureDetector(
                            onLongPress: () => editDay(i),
                            onDoubleTap: () => deleteDay(i),
                            child: Container(
                              padding: EdgeInsets.all(12),
                              color: Colors.deepPurple.shade100,
                              child: Text(day,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                  textAlign: TextAlign.center),
                            ),
                          );
                        }),
                      ],
                    ),
                    // Time Rows
                    ...times.asMap().entries.map((timeEntry) {
                      int tIndex = timeEntry.key;
                      String fullTime = timeEntry.value;
                      List<String> parts = fullTime.split('|');
                      String time = parts[0];
                      String duration = parts.length > 1 ? parts[1] : "";

                      return TableRow(
                        children: [
                          GestureDetector(
                            onLongPress: () => editTime(tIndex),
                            onDoubleTap: () => deleteTime(tIndex),
                            child: Container(
                              padding: EdgeInsets.all(12),
                              color: Colors.grey.shade200,
                              child: Text("$time\n$duration",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                          ...days.map((day) {
                            String? subject = timetable[day]?[time];
                            Color bgColor = subject != null
                                ? getSubjectColor(subject)
                                : Colors.white;
                            return GestureDetector(
                              onTap: () => showEditDialog(context, userId, day, time, subject),
                              child: Container(
                                padding: EdgeInsets.all(12),
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
              ),
            ),
          );
        },
      ),
    );
  }
}
