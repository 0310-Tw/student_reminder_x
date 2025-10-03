import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:students_reminder/src/services/auth_service.dart';

/// -------------------- Helpers --------------------
class JmTime {
  static DateTime nowLocal() => DateTime.now();

  static String dateId(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return "$y$m$d";
  }

  static String formatDate(DateTime dt) => DateFormat.yMMMd().format(dt);
}

void displaySnackBar(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class SuspensionCheck extends StatelessWidget {
  final Widget child;
  const SuspensionCheck({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// -------------------- Attendance Service --------------------
class AttendanceService {
  static final _firestore = FirebaseFirestore.instance;

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamLast14Days(String uid) {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 14));

    return _firestore
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .where('dayId', isGreaterThanOrEqualTo: _dateId(start))
        .where('dayId', isLessThanOrEqualTo: _dateId(now))
        .snapshots();
  }

  static Future<void> clockIn(String uid, Position pos, String placeName) async {
    final now = DateTime.now();
    final dayId = _dateId(now);

    final data = {
      'dayId': dayId,
      'inAt': Timestamp.fromDate(now),
      'inLoc': GeoPoint(pos.latitude, pos.longitude),
      'placeIn': placeName,
    };

    await _firestore
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .doc(dayId)
        .set(data, SetOptions(merge: true));
  }

  static Future<void> clockOut(String uid, Position pos, String placeName) async {
    final now = DateTime.now();
    final dayId = _dateId(now);

    final docRef = _firestore.collection('attendance').doc(uid).collection('days').doc(dayId);
    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data()?['inAt'] == null) {
      throw Exception("Cannot clock out before clocking in.");
    }

    await docRef.set({
      'outAt': Timestamp.fromDate(now),
      'outLoc': GeoPoint(pos.latitude, pos.longitude),
      'placeOut': placeName,
    }, SetOptions(merge: true));
  }

  static Future<void> updateLiveLocation(String uid, Position pos, String placeName) async {
    final now = DateTime.now();
    final dayId = _dateId(now);

    await _firestore.collection('attendance').doc(uid).collection('days').doc(dayId).set({
      'liveLat': pos.latitude,
      'liveLng': pos.longitude,
      'livePlace': placeName,
      'liveUpdated': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  static String _dateId(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return "$y$m$d";
  }
}

/// -------------------- Main Widget --------------------
class AttendanceHistory14d extends StatefulWidget {
  const AttendanceHistory14d({super.key});

  @override
  State<AttendanceHistory14d> createState() => _AttendanceHistory14dState();
}

class _AttendanceHistory14dState extends State<AttendanceHistory14d> {
  bool _showCalendar = false;
  StreamSubscription<Position>? _locationSub;
  Timer? _autoClockOutTimer;

  @override
  void initState() {
    super.initState();
    _scheduleAutoClockOut();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _autoClockOutTimer?.cancel();
    super.dispose();
  }

  /// ---------------- Location Helpers ----------------
  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'Location services disabled';

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw 'Location permission denied';
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String> _getPlaceName(Position pos) async {
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return "${p.name ?? ''}, ${p.locality ?? ''}".trim();
      }
    } catch (_) {}
    return "Unknown location";
  }

  /// ---------------- Clock In/Out ----------------
  Future<void> _clockIn(String uid) async {
    try {
      final pos = await _getLocation();
      final placeName = await _getPlaceName(pos);
      await AttendanceService.clockIn(uid, pos, placeName);
      displaySnackBar(context, "Clocked In at $placeName");
      _startLiveTracking(uid);
      _scheduleAutoClockOut(); // reschedule auto clock-out after clock-in
    } catch (e) {
      displaySnackBar(context, "Clock In failed: $e");
    }
  }

  Future<void> _clockOut(String uid) async {
    try {
      final pos = await _getLocation();
      final placeName = await _getPlaceName(pos);
      await AttendanceService.clockOut(uid, pos, placeName);
      displaySnackBar(context, "Clocked Out at $placeName");
      _stopLiveTracking();
      _autoClockOutTimer?.cancel();
    } catch (e) {
      displaySnackBar(context, "Clock Out failed: $e");
    }
  }

  /// ---------------- Live Tracking ----------------
  Future<void> _startLiveTracking(String uid) async {
    _locationSub?.cancel();
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      final placeName = await _getPlaceName(pos);
      await AttendanceService.updateLiveLocation(uid, pos, placeName);
    });
  }

  Future<void> _stopLiveTracking() async {
    await _locationSub?.cancel();
    _locationSub = null;
  }

  /// ---------------- Auto Clock Out ----------------
  void _scheduleAutoClockOut() {
    _autoClockOutTimer?.cancel();

    final now = DateTime.now();
    final clockOutTime = DateTime(now.year, now.month, now.day, 16, 0); // 4 PM
    Duration durationUntil4PM = clockOutTime.difference(now);

    if (durationUntil4PM.isNegative) {
      // Already past 4 PM today, no timer needed
      return;
    }

    _autoClockOutTimer = Timer(durationUntil4PM, () async {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await _clockOut(currentUser.uid);
        displaySnackBar(context, "Automatically Clocked Out at 4 PM");
      }
    });
  }

  /// ---------------- Build Widget ----------------
  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view attendance')),
      );
    }
    final uid = currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance • Last 14 days'),
        actions: [
          IconButton(
            tooltip: _showCalendar ? 'Show list' : 'Show calendar',
            icon: Icon(_showCalendar ? Icons.view_list : Icons.calendar_month),
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
          ),
        ],
      ),
      body: SuspensionCheck(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _clockIn(uid),
                      icon: const Icon(Icons.login),
                      label: const Text("Clock In"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _clockOut(uid),
                      icon: const Icon(Icons.logout),
                      label: const Text("Clock Out"),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AttendanceService.streamLast14Days(uid),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs;
                  final byDate = {for (var d in docs) d.data()['dayId'] as String: d.data()};
                  final end = DateTime.now();
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
}

/// -------------------- Day Item --------------------
class _DayItem {
  final DateTime date;
  final String dateId;
  final Map<String, dynamic>? data;
  _DayItem({required this.date, required this.dateId, this.data});
}

/// -------------------- History List --------------------
class _HistoryList extends StatelessWidget {
  final String uid;
  final List<_DayItem> days;
  const _HistoryList({required this.uid, required this.days});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: days.map((d) {
        final data = d.data;
        final clockIn = data?['inAt'] != null ? (data!['inAt'] as Timestamp).toDate() : null;
        final clockOut = data?['outAt'] != null ? (data!['outAt'] as Timestamp).toDate() : null;

        return ListTile(
          title: Text(JmTime.formatDate(d.date)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (clockIn != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Clock In: ${_fmtJM(clockIn)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (data?['placeIn'] != null)
                      Text(
                        data!['placeIn'],
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              if (clockOut != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Clock Out: ${_fmtJM(clockOut)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (data?['placeOut'] != null)
                      Text(
                        data!['placeOut'],
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              if (data?['livePlace'] != null)
                Text(
                  "Live: ${data!['livePlace']}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          onTap: data != null
              ? () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => DayMapModal(uid: uid, dayId: d.dateId),
                  );
                }
              : null,
        );
      }).toList(),
    );
  }
}

/// -------------------- Calendar Grid Placeholder --------------------
class _CalendarGrid extends StatelessWidget {
  final String uid;
  final List<_DayItem> days;
  const _CalendarGrid({required this.uid, required this.days});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Calendar view coming soon..."));
  }
}

/// -------------------- Day Map Modal --------------------
class DayMapModal extends StatelessWidget {
  final String uid;
  final String dayId;
  const DayMapModal({super.key, required this.uid, required this.dayId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .doc(uid)
          .collection('days')
          .doc(dayId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = snap.data!.data() ?? {};

        final inAt = (data['inAt'] as Timestamp?)?.toDate();
        final outAt = (data['outAt'] as Timestamp?)?.toDate();
        final inLoc = data['inLoc'] != null
            ? LatLng(data['inLoc'].latitude, data['inLoc'].longitude)
            : null;
        final outLoc = data['outLoc'] != null
            ? LatLng(data['outLoc'].latitude, data['outLoc'].longitude)
            : null;
        final liveLoc = (data['liveLat'] != null && data['liveLng'] != null)
            ? LatLng(data['liveLat'], data['liveLng'])
            : null;

        final markers = <Marker>{};
        if (inLoc != null) {
          markers.add(Marker(
              markerId: const MarkerId("in"),
              position: inLoc,
              infoWindow: InfoWindow(
                  title: "Clock In",
                  snippet: "${_fmtJM(inAt)} • ${data['placeIn'] ?? ''}")));
        }
        if (outLoc != null) {
          markers.add(Marker(
              markerId: const MarkerId("out"),
              position: outLoc,
              infoWindow: InfoWindow(
                  title: "Clock Out",
                  snippet: "${_fmtJM(outAt)} • ${data['placeOut'] ?? ''}")));
        }
        if (liveLoc != null) {
          markers.add(Marker(
            markerId: const MarkerId("live"),
            position: liveLoc,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(title: "Live Location", snippet: data['livePlace'] ?? ''),
          ));
        }

        final center = liveLoc ?? outLoc ?? inLoc ?? const LatLng(18.005, -76.7936);

        return DraggableScrollableSheet(
          expand: false,
          minChildSize: 0.5,
          initialChildSize: 0.75,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  height: 5,
                  width: 40,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                ),
                Text("Day: $dayId"),
                if (inAt != null) Text("Clock In: ${_fmtJM(inAt)} • ${data['placeIn'] ?? ''}"),
                if (outAt != null) Text("Clock Out: ${_fmtJM(outAt)} • ${data['placeOut'] ?? ''}"),
                if (liveLoc != null) Text("Live: ${data['livePlace'] ?? ''}"),
                const SizedBox(height: 8),
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: center, zoom: 15),
                    markers: markers,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// -------------------- Utils --------------------
String _fmtJM(DateTime? t) => t == null ? '—' : DateFormat.jm().format(t);
