// lib/src/history/attendance_history.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'package:students_reminder/src/services/attendance_service.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/shared/misc.dart';
import 'package:students_reminder/src/widgets/atrisk_banner_notifications.dart';
import 'package:students_reminder/src/widgets/suspension_check.dart';


class CampusZone {
  final String name;
  final LatLng center;
  final double radiusMeters;
  CampusZone({
    required this.name,
    required this.center,
    required this.radiusMeters,
  });
}

final CampusZone upParkCampZone = CampusZone(
  name: "Up Park Camp",
  center: LatLng(17.98333, -76.76667),
  radiusMeters: 150,
);

final CampusZone stonyHillZone = CampusZone(
  name: "Stony Hill Campus",
  center: LatLng(18.07916, -76.78473),
  radiusMeters: 150,
);

// ==================== Main Attendance Screen ====================
class AttendanceHistory14d extends StatefulWidget {
  const AttendanceHistory14d({super.key});
  @override
  State<AttendanceHistory14d> createState() => _AttendanceHistory14dState();
}

class _AttendanceHistory14dState extends State<AttendanceHistory14d> {
  bool _showCalendar = false;
  bool _isClockedIn = false;
  StreamSubscription<Position>? _locationSub;
  Timer? _autoClockOutTimer;
  bool _isInsideZone = false;

  @override
  void initState() {
    super.initState();
    _loadTodayClockStatus();
    _scheduleAutoClockOut();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _autoClockOutTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTodayClockStatus() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final todayDoc = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .doc(JmTime.dateId(DateTime.now()))
        .get();

    if (!mounted) return;
    setState(() {
      _isClockedIn = todayDoc.exists &&
          todayDoc.data()?['inAt'] != null &&
          todayDoc.data()?['outAt'] == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view attendance")),
      );
    }

    final uid = user.uid;
    final now = JmTime.nowLocal();
    final end = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        title: const Text("Attendance • Last 14 Days"),
        actions: [
          IconButton(
            tooltip: _showCalendar ? 'Show list' : 'Show calendar',
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
            icon: Icon(_showCalendar ? Icons.view_list : Icons.calendar_month),
          ),
        ],
      ),
      body: SuspensionCheck(
        child: Column(
          children: [
            AtRiskBannerNotifications(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_isClockedIn) {
                    await _clockOut(uid);
                  } else {
                    await _clockIn(uid);
                  }
                  await _loadTodayClockStatus();
                },
                icon: Icon(
                  _isClockedIn ? Icons.logout : Icons.login,
                  size: 16,
                ),
                label: Text(
                  _isClockedIn ? "Clock Out" : "Clock In",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isClockedIn
                      ? const Color(0xFFE74C3C)
                      : const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AttendanceService.streamLast14Days(uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text("Error: ${snap.error}"));
                  }

                  final docs = snap.data?.docs ?? [];
                  final byDate = {
                    for (final d in docs) (d.data()['dayId'] as String): d.data()
                  };

                  final items = <_DayItem>[];
                  for (int i = 13; i >= 0; i--) {
                    final day = end.subtract(Duration(days: i));
                    final id = JmTime.dateId(day);
                    items.add(_DayItem(date: day, dateId: id, data: byDate[id]));
                  }

                  return _showCalendar
                      ? _CalendarGrid(uid: uid, days: items)
                      : _HistoryList(uid: uid, days: items);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Clock In ----------------
  Future<void> _clockIn(String uid) async {
    final now = DateTime.now();
    final eightAM = DateTime(now.year, now.month, now.day, 8, 0);
    final eightThirty = DateTime(now.year, now.month, now.day, 8, 30);

    Position location;
    try {
      location = await _getLocation();
    } catch (e) {
      _showSnack("Location error: $e");
      return;
    }

    // Determine if user is within zone
    final zoneData = _getNearestZone(location);
    if (!zoneData['inside']) {
      _showSnack(
          "You are ${(zoneData['distance'] as double).toStringAsFixed(0)}m away from ${zoneData['zone'].name}. Move closer to clock in.");
      return;
    }

    String status;
    String? reason;
    if (now.isBefore(eightAM)) {
      _showSnack("Too early to clock in.");
      return;
    } else if (now.isBefore(eightThirty)) {
      status = "present";
    } else if (now.isBefore(DateTime(now.year, now.month, now.day, 16))) {
      status = "late";
      reason = await _askLateReason();
      if (reason == null || reason.trim().isEmpty) {
        _showSnack("Late reason required.");
        return;
      }
    } else {
      _showSnack("Too late to clock in.");
      return;
    }

    final placeName = await _getPlaceName(location);
    final finalPlace = zoneData['zone'].name;

    try {
      await AttendanceService.clockIn(uid, location, finalPlace);
      final ref = FirebaseFirestore.instance
          .collection('attendance')
          .doc(uid)
          .collection('days')
          .doc(JmTime.dateId(now));
      await ref.set({
        'status': status,
        'placeIn': finalPlace,
        if (reason != null) 'lateReason': reason,
      }, SetOptions(merge: true));
    } catch (e) {
      _showSnack("Clock in failed: $e");
      return;
    }

    await _startLiveTracking(uid);
    _scheduleAutoClockOut();
    _showSnack("Clocked in at $finalPlace ($status)");
  }

  // ---------------- Clock Out ----------------
  Future<void> _clockOut(String uid) async {
    final now = DateTime.now();

    Position location;
    try {
      location = await _getLocation();
    } catch (e) {
      _showSnack("Location error: $e");
      return;
    }

    final zoneData = _getNearestZone(location);
    if (!zoneData['inside']) {
      _showSnack(
          "You are ${(zoneData['distance'] as double).toStringAsFixed(0)}m away from ${zoneData['zone'].name}. Move closer to clock out.");
      return;
    }

    final placeName = zoneData['zone'].name;

    try {
      await AttendanceService.clockOut(uid, location, placeName);
      final ref = FirebaseFirestore.instance
          .collection('attendance')
          .doc(uid)
          .collection('days')
          .doc(JmTime.dateId(now));
      await ref.set({
        'placeOut': placeName,
      }, SetOptions(merge: true));
    } catch (e) {
      _showSnack("Clock out failed: $e");
      return;
    }

    await _stopLiveTracking();
    _autoClockOutTimer?.cancel();
    _showSnack("Clocked out successfully at $placeName");
  }

  Map<String, dynamic> _getNearestZone(Position pos) {
    final distUp = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      upParkCampZone.center.latitude,
      upParkCampZone.center.longitude,
    );
    final distStony = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      stonyHillZone.center.latitude,
      stonyHillZone.center.longitude,
    );

    final nearer = distUp < distStony ? upParkCampZone : stonyHillZone;
    final dist = math.min(distUp, distStony);
    return {'zone': nearer, 'distance': dist, 'inside': dist <= nearer.radiusMeters};
  }

  // ---------------- Helpers ----------------
  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'Location disabled';
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        throw 'Permission denied';
      }
    }
    return Geolocator.getCurrentPosition();
  }

  Future<String> _getPlaceName(Position pos) async {
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return "${p.name ?? ''}, ${p.locality ?? ''}";
      }
    } catch (_) {}
    return "Unknown location";
  }

  Future<String?> _askLateReason() async {
    String reason = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Late Reason'),
        content: TextField(
          autofocus: true,
          onChanged: (v) => reason = v,
          decoration: const InputDecoration(hintText: 'Enter reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, reason), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showSnack(String msg) => displaySnackBar(context, msg);

  void _scheduleAutoClockOut() {
    _autoClockOutTimer?.cancel();
    final now = DateTime.now();
    final clockOutTime = DateTime(now.year, now.month, now.day, 16);
    final dur = clockOutTime.difference(now);
    if (dur.isNegative) return;
    _autoClockOutTimer = Timer(dur, () async {
      final user = AuthService.instance.currentUser;
      if (user != null && _isClockedIn) {
        await _clockOut(user.uid);
        await _loadTodayClockStatus();
        _showSnack("Auto clocked out at 4:00 PM");
      }
    });
  }

  Future<void> _startLiveTracking(String uid) async {
    _locationSub?.cancel();
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((pos) async {
      final place = await _getPlaceName(pos);
      await _updateLiveLocation(uid, pos, place);
      await _checkGeofence(pos);
    });
  }

  Future<void> _stopLiveTracking() async {
    await _locationSub?.cancel();
    _locationSub = null;
  }

  Future<void> _updateLiveLocation(String uid, Position pos, String place) async {
    final now = DateTime.now();
    final dayId = JmTime.dateId(now);
    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .doc(dayId)
        .set({
      'liveLat': pos.latitude,
      'liveLng': pos.longitude,
      'livePlace': place,
      'liveUpdated': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> _checkGeofence(Position pos) async {
    final zoneData = _getNearestZone(pos);
    final inside = zoneData['inside'] as bool;
    if (inside != _isInsideZone) {
      _isInsideZone = inside;
      if (inside) {
        _showSnack("✔️ Entered ${zoneData['zone'].name}");
      } else if (_isClockedIn) {
        await _clockOut(AuthService.instance.currentUser!.uid);
        _showSnack("Auto clocked out — left ${zoneData['zone'].name}");
      }
    }
  }
}

// ==================== Helpers, Lists & Map Modal ====================

class _DayItem {
  final DateTime date;
  final String dateId;
  final Map<String, dynamic>? data;
  _DayItem({required this.date, required this.dateId, this.data});
}

class _HistoryList extends StatelessWidget {
  final String uid;
  final List<_DayItem> days;
  const _HistoryList({required this.uid, required this.days, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: days.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final item = days[i];
        final status = item.data?['status'] ?? 'absent';
        final color = status == 'present'
            ? Colors.green
            : status == 'late'
                ? Colors.orange
                : Colors.red;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: color,
            child: Text(DateFormat('d').format(item.date)),
          ),
          title: Text(DateFormat('EEEE, MMM d').format(item.date)),
          subtitle: Text(status.toUpperCase()),
          trailing: IconButton(
            icon: const Icon(Icons.map),
            onPressed: item.data == null
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (_) => DayMapModal(item: item),
                    );
                  },
          ),
        );
      },
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final String uid;
  final List<_DayItem> days;
  const _CalendarGrid({required this.uid, required this.days, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final item = days[i];
        final status = item.data?['status'] ?? 'absent';
        final color = status == 'present'
            ? Colors.green
            : status == 'late'
                ? Colors.orange
                : Colors.red;
        return GestureDetector(
          onTap: item.data == null
              ? null
              : () {
                  showDialog(
                    context: context,
                    builder: (_) => DayMapModal(item: item),
                  );
                },
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 1),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(DateFormat('d').format(item.date),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 18)),
                Text(DateFormat('E').format(item.date),
                    style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DayMapModal extends StatelessWidget {
  final _DayItem item;
  const DayMapModal({required this.item, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lat = item.data?['liveLat'];
    final lng = item.data?['liveLng'];
    if (lat == null || lng == null) {
      return AlertDialog(
        title: const Text('No Location Data'),
        content: const Text('No location was recorded for this day.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final place = item.data?['livePlace'] ?? 'Unknown';
    return AlertDialog(
      title: Text('Location for ${DateFormat('MMM d, yyyy').format(item.date)}'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(lat, lng),
            zoom: 17,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('attendance'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(title: place),
            ),
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
