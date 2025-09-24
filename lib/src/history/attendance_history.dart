import 'dart:math';

//import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:students_reminder/src/history/shift_timeline.dart';
import 'package:students_reminder/src/services/attendance_service.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/shared/misc.dart';
import 'package:students_reminder/src/widgets/suspension_check.dart';

class AttendanceHistory14d extends StatefulWidget {
  const AttendanceHistory14d({super.key});

  @override
  State<AttendanceHistory14d> createState() => _AttendanceHistory14dState();
}

class _AttendanceHistory14dState extends State<AttendanceHistory14d> {
  bool _showCalendar = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view attendance')),
      );
    }

    final uid = currentUser.uid;
    final now = JmTime.nowLocal();
    final end = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Attendance • Last 14 days'),
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
            // Clock In / Clock Out buttons
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _clockIn(uid),
                      icon: const Icon(Icons.login),
                      label: const Text("Clock In"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3498DB),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _clockOut(uid),
                      icon: const Icon(Icons.logout),
                      label: const Text("Clock Out"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFE74C3C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AttendanceService.streamLast14Days(uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs =
                      snap.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final byDate = {
                    for (final d in docs)
                      (d.data()['dayId'] as String): d.data(),
                  };

                  final items = <_DayItem>[];
                  for (int i = 13; i >= 0; i--) {
                    final day = end.subtract(Duration(days: i));
                    final id = JmTime.dateId(day);
                    items.add(
                      _DayItem(date: day, dateId: id, data: byDate[id]),
                    );
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

  // ------------------ Clock In ------------------
  Future<void> _clockIn(String uid) async {
    final now = DateTime.now();
    final eightAM = DateTime(now.year, now.month, now.day, 8, 0);
    final eightThirty = DateTime(now.year, now.month, now.day, 8, 30);

    Position? location;
    try {
      location = await _getLocation();
    } catch (e) {
      _showSnack("Location error: $e");
      return;
    }

    String status;
    String? reason;
    if (now.isAfter(eightAM) && now.isBefore(eightThirty)) {
      status = "early";
    } else if (now.isAfter(eightThirty) &&
        now.isBefore(DateTime(now.year, now.month, now.day, 16))) {
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

    final attendanceData = {
      'dayId': JmTime.dateId(now),
      'inAt': Timestamp.fromDate(now),
      'inLoc': GeoPoint(location.latitude, location.longitude),
      'status': status,
    };

    if (reason != null && reason.trim().isNotEmpty) {
      attendanceData['lateReason'] = reason.trim();
    }

    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .doc(JmTime.dateId(now))
        .set(attendanceData, SetOptions(merge: true));

    final displayMessage = reason != null && reason.trim().isNotEmpty
        ? "Clocked in: $status (Reason: $reason) at ${location.latitude}, ${location.longitude}"
        : "Clocked in: $status at ${location.latitude}, ${location.longitude}";

    _showSnack(displayMessage);
  }

  // ------------------ Clock Out ------------------
  Future<void> _clockOut(String uid) async {
    final now = DateTime.now();

    Position? location;
    try {
      location = await _getLocation();
    } catch (e) {
      _showSnack("Location error: $e");
      return;
    }

    final dayDoc = FirebaseFirestore.instance
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .doc(JmTime.dateId(now));

    final snapshot = await dayDoc.get();
    if (!snapshot.exists || snapshot.data()?['inAt'] == null) {
      _showSnack("Cannot clock out before clocking in.");
      return;
    }

    await dayDoc.set({
      'outAt': Timestamp.fromDate(now),
      'outLoc': GeoPoint(location.latitude, location.longitude),
    }, SetOptions(merge: true));

    _showSnack("Clocked out at ${location.latitude}, ${location.longitude}");
  }

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

  Future<String?> _askLateReason() async {
    String reason = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Late Reason'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => reason = value,
          decoration: const InputDecoration(hintText: 'Why are you late?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reason),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    displaySnackBar(context, msg);
  }
}

// ------------------ Models + Helpers ------------------

class _DayItem {
  final DateTime date;
  final String dateId;
  final Map<String, dynamic>? data;
  _DayItem({required this.date, required this.dateId, required this.data});

  String get rawStatus => (data?['status'] ?? 'absent').toString();

  String get status {
    if (rawStatus.toLowerCase().startsWith('present')) return 'present';
    if (rawStatus.toLowerCase().startsWith('early')) return 'early';
    if (rawStatus.toLowerCase().startsWith('late')) return 'late';
    if (rawStatus.toLowerCase().startsWith('in_progress')) return 'in_progress';
    return 'absent';
  }

  String? get reason {
    if (rawStatus.contains('— Reason:')) {
      return rawStatus.split('— Reason:')[1].trim();
    }
    return data?['lateReason'] as String?;
  }

  DateTime? get inAt {
    final timestamp = data?['inAt'] ?? data?['clockInAt'];
    return (timestamp as Timestamp?)?.toDate();
  }

  DateTime? get outAt {
    final timestamp = data?['outAt'] ?? data?['clockOutAt'];
    return (timestamp as Timestamp?)?.toDate();
  }

  bool get isAdminMarked => data?['adminMarked'] == true;
  String? get markedByAdminName => data?['markedByAdminName'] as String?;
  String? get markedByAdminEmail => data?['markedByAdminEmail'] as String?;
  DateTime? get markedAt => (data?['markedAt'] as Timestamp?)?.toDate();
}

Color _statusColor(String status) {
  switch (status) {
    case 'present':
      return Color(0xFF27AE60); // Sage Green
    case 'early':
      return Color(0xFF27AE60); // Sage Green
    case 'late':
      return Color(0xFFF39C12); // Warm Amber
    case 'in_progress':
      return Color(0xFF3498DB); // Sky Blue
    case 'absent':
    default:
      return Color(0xFFE74C3C); // Soft Red
  }
}

Widget _statusBadgeWithAdmin(_DayItem dayItem) {
  final status = dayItem.status;
  final reason = dayItem.reason;
  final c = _statusColor(status);

  String displayText = status.toUpperCase();
  if (reason != null && reason.isNotEmpty) {
    displayText += '\n$reason';
  }

  if (dayItem.isAdminMarked) {
    displayText += '\n👤Admin';
    if (dayItem.markedByAdminName != null) {
      displayText += ': ${dayItem.markedByAdminName}';
    }
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      border: Border.all(
        color: dayItem.isAdminMarked
            ? Color(0xFF8E44AD).withOpacity(0.8)
            : c.withOpacity(0.6),
        width: dayItem.isAdminMarked ? 2 : 1,
      ),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      displayText,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: dayItem.isAdminMarked ? Color(0xFF8E44AD) : c,
      ),
      textAlign: TextAlign.center,
    ),
  );
}

// ignore: unused_element
Widget _statusChip(String status, [String? reason]) {
  Color c;
  String label = status.toUpperCase();
  switch (status.toLowerCase()) {
    case 'early':
      c = Colors.green;
      break;
    case 'late':
      c = Colors.orange;
      break;
    case 'in_progress':
      c = Colors.blue;
      break;
    case 'absent':
    default:
      c = Colors.red;
      label = 'ABSENT';
  }
  if (reason != null) label += '\n$reason';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      border: Border.all(color: c.withOpacity(0.6)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
      textAlign: TextAlign.center,
    ),
  );
}

String _fmtJM(DateTime? t) => t == null ? '—' : DateFormat.jm().format(t);

// ------------------ List View ------------------

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.uid, required this.days});
  final String uid;
  final List<_DayItem> days;

  // ✅ Status color helper
  Color _statusColor(String status) {
    switch (status) {
      case 'Early':
        return Colors.green;
      case 'Late':
        return Colors.orange;
      case 'Absent':
        return Colors.red;
      case 'In progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: days.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final d = days[i];
        final dateLabel = DateFormat('EEE, MMM d').format(d.date);

        return ListTile(
          title: Text(dateLabel),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (d.inAt != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text('In: ${_fmtJM(d.inAt)}'),
                    ),
                  if (d.outAt != null) Text('Out: ${_fmtJM(d.outAt)}'),
                ],
              ),
              const SizedBox(height: 6),
              // Shift timeline with status color
              SizedBox(
                height: 20,
                child: ShiftTimeline(
                  clockIn: d.inAt,
                  clockOut: d.outAt,
                  color: _statusColor(d.status), // Use status color 
                ),
              ),
            ],
          ),
          trailing: _statusBadgeWithAdmin(d),
          onTap: () => _openMapModal(context, uid: uid, dayId: d.dateId),
        );
      },
    );
  }
}

// ------------------ Calendar Grid ------------------

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.uid, required this.days});
  final String uid;
  final List<_DayItem> days;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: const [
              _Legend(color: Colors.green, label: 'Early'),
              _Legend(color: Colors.orange, label: 'Late'),
              _Legend(color: Colors.red, label: 'Absent'),
              _Legend(color: Colors.blue, label: 'In progress'),
            ],
          ),
          const SizedBox(height: 12),
          // Grid
          Expanded(
            child: GridView.builder(
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.8, // Adjusted for better spacing
              ),
              itemBuilder: (context, i) {
                final d = days[i];
                final dot = _statusColor(d.status);

                return InkWell(
                  onTap: () => _openMapModal(context, uid: uid, dayId: d.dateId),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Day number
                        Text(
                          DateFormat('d').format(d.date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Status dot with mini timeline inside
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background circle (lighter)
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: dot.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              // Mini timeline bar
                              FractionallySizedBox(
                                widthFactor: d.inAt != null && d.outAt != null ? 1.0 : 0.0,
                                heightFactor: 0.3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: dot,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ------------------ Map Modal ------------------


void _openMapModal(BuildContext context,
    {required String uid, required String dayId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DayMapModal(uid: uid, dayId: dayId),
  );
}

class DayMapModal extends StatefulWidget {
  const DayMapModal({super.key, required this.uid, required this.dayId});
  final String uid;
  final String dayId;

  @override
  State<DayMapModal> createState() => _DayMapModalState();
}

class _DayMapModalState extends State<DayMapModal> {
  GoogleMapController? _controller;
  bool _mapReady = false;
  LatLng? _inLoc;
  LatLng? _outLoc;
  String status = 'absent';
  DateTime? inAt;
  DateTime? outAt;

  String? inAddress;
  String? outAddress;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final ref = FirebaseFirestore.instance
        .collection('attendance')
        .doc(widget.uid)
        .collection('days')
        .doc(widget.dayId);
    final snap = await ref.get();
    if (!mounted) return;
    final data = snap.data();
    if (data != null) {
      final inTimestamp = data['inAt'] ?? data['clockInAt'];
      final outTimestamp = data['outAt'] ?? data['clockOutAt'];

      _inLoc = _toLatLng(data['inLoc'] ?? data['clockInLoc']);
      _outLoc = _toLatLng(data['outLoc'] ?? data['clockOutLoc']);
      inAt = (inTimestamp as Timestamp?)?.toDate();
      outAt = (outTimestamp as Timestamp?)?.toDate();
      status = (data['status'] ?? 'absent').toString();
    }
    if (_inLoc != null) {
      inAddress = await _reverseGeocode(_inLoc!);
    }
    if (_outLoc != null) {
      outAddress = await _reverseGeocode(_outLoc!);
    }
    if (mounted) setState(() {});
  }

  LatLng? _toLatLng(dynamic v) {
    if (v == null) return null;
    if (v is GeoPoint) return LatLng(v.latitude, v.longitude);
    return null;
  }

  Future<String?> _reverseGeocode(LatLng pos) async {
    try {
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        return "${pm.street}, ${pm.locality}, ${pm.country}";
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    if (_inLoc != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("in"),
          position: _inLoc!,
          infoWindow: InfoWindow(
            title: "Clocked In",
            snippet: inAddress ?? _fmtJM(inAt),
          ),
        ),
      );
    }
    if (_outLoc != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("out"),
          position: _outLoc!,
          infoWindow: InfoWindow(
            title: "Clocked Out",
            snippet: outAddress ?? _fmtJM(outAt),
          ),
        ),
      );
    }

    final center = _outLoc ?? _inLoc ?? const LatLng(18.005, -76.7936);

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
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Text("Day: ${widget.dayId}"),
            Text("Status: $status"),
            if (inAt != null) Text("Clock In: ${_fmtJM(inAt)}"),
            if (outAt != null) Text("Clock Out: ${_fmtJM(outAt)}"),
            const SizedBox(height: 8),
            if (!_mapReady)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: center, zoom: 15),
                  onMapCreated: (c) {
                    _controller = c;
                    setState(() => _mapReady = true);
                  },
                  markers: markers,
                ),
              ),
          ],
        );
      },
    );
  }
}