import 'package:flutter/material.dart';
import 'package:students_reminder/src/models/timetable_model.dart';
import 'package:students_reminder/src/timetable/timetable_display.dart';
import 'package:students_reminder/src/widgets/suspension_check.dart';

class TimetableGeneratorScreen extends StatefulWidget {
  const TimetableGeneratorScreen({super.key});

  @override
  _TimetableGeneratorScreenState createState() =>
      _TimetableGeneratorScreenState();
}

class _TimetableGeneratorScreenState extends State<TimetableGeneratorScreen> {
  final List<String> allDays = ["Mon", "Tue", "Wed", "Thu", "Fri"];
  final List<String> allTimes = ["8-9", "9-10", "10-11", "11-12"];

  final TextEditingController _subjectController = TextEditingController();

  String? selectedDay;
  String? selectedTime;

  final List<TimetableEntry> entries = [];

  void addEntry() {
    final subject = _subjectController.text.trim();

    if (subject.isEmpty || selectedDay == null || selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields.')));
      return;
    }

    // Prevent duplicate time-slot entry
    final alreadyExists = entries.any(
      (e) => e.day == selectedDay && e.time == selectedTime,
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This time slot already has a subject!')),
      );
      return;
    }

    setState(() {
      entries.add(
        TimetableEntry(
          day: selectedDay!,
          time: selectedTime!,
          subject: subject,
        ),
      );
      _subjectController.clear();
      selectedDay = null;
      selectedTime = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Course added!')));
  }

  void generateTimetable() {
    if (entries.isNotEmpty) {
      Map<String, Map<String, String>> timetableMap = {};
      for (var entry in entries) {
        timetableMap.putIfAbsent(entry.day, () => {});
        timetableMap[entry.day]![entry.time] = entry.subject;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TimetableDisplayScreen(
            timetable: timetableMap,
            days: allDays,
            times: allTimes,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one course first.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Your Timetable"),
        centerTitle: true,
      ),
      body: SuspensionCheck(
        restrictWriteAccess: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: "Course Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Select Day",
                        border: OutlineInputBorder(),
                      ),
                      value: selectedDay,
                      items: allDays.map((day) {
                        return DropdownMenuItem(value: day, child: Text(day));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedDay = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Select Time",
                        border: OutlineInputBorder(),
                      ),
                      value: selectedTime,
                      items: allTimes.map((time) {
                        return DropdownMenuItem(value: time, child: Text(time));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedTime = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: addEntry,
                icon: const Icon(Icons.add),
                label: const Text("Add Course"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Courses to be added: (${entries.length})",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              entries.isEmpty
                  ? const Text(
                      "No courses added yet.",
                      style: TextStyle(color: Colors.grey),
                    )
                  : Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: entries.map((e) {
                        return Chip(
                          label: Text("${e.subject} (${e.day} ${e.time})"),
                          deleteIcon: const Icon(Icons.close),
                          onDeleted: () {
                            setState(() {
                              entries.remove(e);
                            });
                          },
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "timetable_generate_fab",
        onPressed: generateTimetable,
        label: const Text("Generate Timetable"),
        icon: const Icon(Icons.table_chart),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
