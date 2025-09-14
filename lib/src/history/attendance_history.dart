import 'dart:math';

//import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
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
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A237E),
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
                        backgroundColor: Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        elevation: 2,
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
                        backgroundColor: Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        elevation: 2,
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
      return Colors.green;
    case 'early':
      return Colors.green;
    case 'late':
      return Colors.orange;
    case 'in_progress':
      return Colors.blue;
    case 'absent':
    default:
      return Colors.red;
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
            ? Colors.purple.withOpacity(0.8)
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
        color: dayItem.isAdminMarked ? Colors.purple.shade700 : c,
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

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final d = days[i];
        final dateLabel = DateFormat('EEE, MMM d').format(d.date);
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              dateLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A237E),
              ),
            ),
            subtitle: Row(
              children: [
                if (d.inAt != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      'In: ${_fmtJM(d.inAt)}',
                      style: const TextStyle(color: Color(0xFF424242)),
                    ),
                  ),
                if (d.outAt != null)
                  Text(
                    'Out: ${_fmtJM(d.outAt)}',
                    style: const TextStyle(color: Color(0xFF424242)),
                  ),
              ],
            ),
            trailing: _statusBadgeWithAdmin(d),
            onTap: () => _openMapModal(context, uid: uid, dayId: d.dateId),
          ),
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
          Expanded(
            child: GridView.builder(
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (context, i) {
                final d = days[i];
                final dot = _statusColor(d.status);
                return InkWell(
                  onTap: () =>
                      _openMapModal(context, uid: uid, dayId: d.dateId),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('d').format(d.date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          d.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: dot),
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

void _openMapModal(
  BuildContext context, {
  required String uid,
  required String dayId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
      setState(() {
        status = (data['status'] as String?) ?? 'absent';
        final inTimestamp = data['inAt'] ?? data['clockInAt'];
        inAt = (inTimestamp as Timestamp?)?.toDate();
        final outTimestamp = data['outAt'] ?? data['clockOutAt'];
        outAt = (outTimestamp as Timestamp?)?.toDate();
        _inLoc = _toLatLng(data['inLoc'] ?? data['clockInLoc']);
        _outLoc = _toLatLng(data['outLoc'] ?? data['clockOutLoc']);
        _mapReady = true;
      });
    }
  }

  LatLng? _toLatLng(dynamic v) {
    if (v is GeoPoint) return LatLng(v.latitude, v.longitude);
    if (v is Map<String, dynamic> && v.containsKey('latitude')) {
      return LatLng(v['latitude'], v['longitude']);
    }
    return null;
  }

  LatLngBounds _latLngBoundsFrom(LatLng a, LatLng b) {
    final southWest = LatLng(
      min(a.latitude, b.latitude),
      min(a.longitude, b.longitude),
    );
    final northEast = LatLng(
      max(a.latitude, b.latitude),
      max(a.longitude, b.longitude),
    );
    return LatLngBounds(southwest: southWest, northeast: northEast);
  }

  @override
  Widget build(BuildContext context) {
    if (!_mapReady) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final markers = <Marker>{};
    if (_inLoc != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('in'),
          position: _inLoc!,
          infoWindow: InfoWindow(
            title: 'Clock In',
            snippet: inAt != null ? DateFormat.jm().format(inAt!) : null,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }
    if (_outLoc != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('out'),
          position: _outLoc!,
          infoWindow: InfoWindow(
            title: 'Clock Out',
            snippet: outAt != null ? DateFormat.jm().format(outAt!) : null,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    CameraPosition initialCam = const CameraPosition(
      target: LatLng(18.005611, -76.744127),
      zoom: 12,
    );
    if (_inLoc != null) {
      initialCam = CameraPosition(target: _inLoc!, zoom: 15);
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: GoogleMap(
        onMapCreated: (c) async {
          _controller = c;
          if (_inLoc != null && _outLoc != null) {
            final bounds = _latLngBoundsFrom(_inLoc!, _outLoc!);
            await _controller!.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 50),
            );
          } else if (_inLoc != null) {
            await _controller!.animateCamera(
              CameraUpdate.newLatLngZoom(_inLoc!, 15),
            );
          }
        },
        initialCameraPosition: initialCam,
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
