import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:screenshot/screenshot.dart';


class TimetableDisplayScreen extends StatefulWidget {
  final Map<String, Map<String, String>> timetable;
  final List<String> days;
  final List<String> times;

  const TimetableDisplayScreen({
    super.key,
    required this.timetable,
    required this.days,
    required this.times,
  });

  @override
  _TimetableDisplayScreenState createState() => _TimetableDisplayScreenState();
}

class _TimetableDisplayScreenState extends State<TimetableDisplayScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  final Map<String, Color> subjectColors = {
    "Math": Colors.blue.shade200,
    "English": Colors.green.shade200,
    "Science": Colors.orange.shade200,
    "History": Colors.red.shade200,
    "Computer": Colors.purple.shade200,
    "Geography": Colors.teal.shade200,
    "PE": Colors.yellow.shade200,
    "Art": Colors.pink.shade200,
    "Chemistry": Colors.cyan.shade200,
    "Physics": Colors.indigo.shade200,
    "Biology": Colors.lime.shade200,
  };

  Color getSubjectColor(String subject) {
    return subjectColors[subject] ?? Colors.grey.shade200;
  }

  Future<void> saveTimetable() async {
    // Platform-aware permission check
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.storage.request();
    } else {
      status = await Permission.photos.request();
    }

    if (status.isDenied || status.isPermanentlyDenied) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Permission Denied"),
          content: const Text(
              "Photo/storage permission is required to save the timetable. Please enable it in app settings."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("OK"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await openAppSettings();
              },
              child: const Text("Open Settings"),
            ),
          ],
        ),
      );
      return;
    }

    if (status.isGranted) {
      try {
        final image = await screenshotController.capture();
        if (image == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to capture screenshot.')),
          );
          return;
        }

        final result = await ImageGallerySaver.saveImage(
          Uint8List.fromList(image),
          quality: 100,
          name: "Timetable_${DateTime.now().toIso8601String()}",
        );

        // Print to console for debugging
        print("Save result: $result");

        if ((result['isSuccess'] ?? result['success']) == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Timetable downloaded successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download timetable.'),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download timetable: $e')),
        );
      }
    }
  }

  Widget buildTimetableGrid() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: Colors.grey),
        defaultColumnWidth: const FixedColumnWidth(100),
        children: [
          // Header row
          TableRow(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.deepPurple.shade100,
                child: const Text(
                  "Time",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ...widget.days.map(
                (day) => Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.deepPurple.shade100,
                  child: Text(
                    day,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          // Time rows
          ...widget.times.map((time) {
            return TableRow(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey.shade200,
                  child: Text(
                    time,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                ...widget.days.map((day) {
                  String? subject = widget.timetable[day]?[time];
                  Color bgColor =
                      subject != null ? getSubjectColor(subject) : Colors.white;
                  return Container(
                    padding: const EdgeInsets.all(8),
                    alignment: Alignment.center,
                    color: bgColor,
                    child: Text(
                      subject ?? "-",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            subject != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Generated Timetable"),
        centerTitle: true,
      ),
      body: Center(
        child: Screenshot(
          controller: screenshotController,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: buildTimetableGrid(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saveTimetable,
        label: const Text("Download"),
        icon: const Icon(Icons.download),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
