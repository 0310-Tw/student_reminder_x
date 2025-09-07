import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class AttendanceScreen extends StatefulWidget {
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime? clockInAt;
  DateTime? clockOutAt;
  Position? clockInLoc;
  Position? clockOutLoc;
  String? lateReason;

  @override
  void initState() {
    super.initState();
    autoClockOutIfNeeded();
  }

  Future<void> autoClockOutIfNeeded() async {
    DateTime now = DateTime.now();
    DateTime fourPM = DateTime(now.year, now.month, now.day, 16, 0);
    if (clockInAt != null && clockOutAt == null && now.isAfter(fourPM)) {
      Position loc = await _getLocation();
      setState(() {
        clockOutAt = now;
        clockOutLoc = loc;
      });
      _showSnack("Auto clocked out at ${now.toLocal()}");
    }
  }
  // Function to handle clock in
  Future<void> clockIn() async {
    DateTime now = DateTime.now();
    DateTime eightAM = DateTime(now.year, now.month, now.day, 8, 0);
    DateTime eightThirty = DateTime(now.year, now.month, now.day, 8, 30);

    // Check if already clocked in
    Position loc = await _getLocation();
    if (clockInAt != null) {
      _showSnack("You have already clocked in at ${clockInAt!.toLocal()}");
      return;
    }

    // Determine status based on time
    String status;
    if (now.isAfter(eightAM) && now.isBefore(eightThirty)) {
      status = "Early";
    } else if (now.isAfter(eightThirty) && now.isBefore(DateTime(now.year, now.month, now.day, 16))) {
      status = "Late";
      lateReason = await _askLateReason();
      if (lateReason == null) return; // User cancelled
    } else {
      status = "Absent";
    }
  // Record clock-in time and location
    setState(() {
      clockInAt = now;
      clockInLoc = loc;
    });

    _showSnack("Clocked in at $status (${now.toLocal()})");
  }
  // Function to handle clock out
  Future<void> clockOut() async {
    if (clockInAt == null) {
      _showSnack("You haven't clocked in yet!");
      return;
    }
  // Check if already clocked out
    DateTime now = DateTime.now();
    if (now.isBefore(clockInAt!)) {
      _showSnack("You can't clock out before clocking in!");
      return;
    }
    if (clockOutAt != null) {
      _showSnack("You have already clocked out at ${clockOutAt!.toLocal()}");
      return;
    }
    // Record clock-out time and location
    Position loc = await _getLocation();

    // Record clock-out time and location
    setState(() {
      clockOutAt = now;
      clockOutLoc = loc;
    });

    _showSnack("Clocked out at ${now.toLocal()}");
  }
  // Function to get current location
  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services disabled");
    }
  // Check for permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        throw Exception("Location permissions denied");
      }
    }
// Get current position
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

// Function to ask for late reason
  Future<String?> _askLateReason() async {
    String reason = "";
    return await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Late Reason"),
          content: TextField(
            onChanged: (value) => reason = value,
            decoration: InputDecoration(hintText: "Enter reason for being late"),
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context, null),
            ),
            ElevatedButton(
              child: Text("Submit"),
              onPressed: () => Navigator.pop(context, reason.trim()),
            ),
          ],
        );
      },
    );
  }

  // Function to show snack messages
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Attendance')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: clockIn,
              child: Text('Clock In'),
            ),
            ElevatedButton(
              onPressed: clockOut,
              child: Text('Clock Out'),
            ),
            SizedBox(height: 20),
            if (clockInAt != null) Text("Clocked In: ${clockInAt!.toLocal()}"),
            if (clockOutAt != null) Text("Clocked Out: ${clockOutAt!.toLocal()}"),
            if (lateReason != null) Text("Late Reason: $lateReason"),
          ],
        ),
      ),
    );
  }
}
