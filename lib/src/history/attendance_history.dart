import 'dart:math';

//import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
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
                color: Color(0xFF2C3E50),
              ),
            ),
            subtitle: Row(
              children: [
                if (d.inAt != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      'In: ${_fmtJM(d.inAt)}',
                      style: const TextStyle(color: Color(0xFF5D6D7E)),
                    ),
                  ),
                if (d.outAt != null)
                  Text(
                    'Out: ${_fmtJM(d.outAt)}',
                    style: const TextStyle(color: Color(0xFF5D6D7E)),
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
              _Legend(color: Color(0xFF27AE60), label: 'Early'),
              _Legend(color: Color(0xFFF39C12), label: 'Late'),
              _Legend(color: Color(0xFFE74C3C), label: 'Absent'),
              _Legend(color: Color(0xFF3498DB), label: 'In progress'),
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
                childAspectRatio: 1.0,
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
                      border: Border.all(color: Color(0xFFE8F4FD)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF2C3E50).withOpacity(0.08),
                          blurRadius: 6,
                          offset: Offset(0, 3),
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
                            color: Color(0xFF2C3E50),
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

// ------------------ Update Map Modal ------------------
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

      // Start with placeholders
      inAddress = _inLoc != null ? "Fetching..." : null;
      outAddress = _outLoc != null ? "Fetching..." : null;

      setState(() {
        status = (data['status'] as String?) ?? 'absent';
        _mapReady = true;
      });

      // 🔄 Fetch addresses in the background, then refresh UI
      if (_inLoc != null) {
        _getAddressFromLatLng(_inLoc!).then((addr) {
          if (mounted) {
            setState(() => inAddress = addr);
          }
        });
      }
      if (_outLoc != null) {
        _getAddressFromLatLng(_outLoc!).then((addr) {
          if (mounted) {
            setState(() => outAddress = addr);
          }
        });
      }
    }
  }

  LatLng? _toLatLng(dynamic v) {
    if (v is GeoPoint) return LatLng(v.latitude, v.longitude);
    if (v is Map<String, dynamic> && v.containsKey('latitude')) {
      return LatLng(v['latitude'], v['longitude']);
    }
    return null;
  }

  Future<String> _getAddressFromLatLng(LatLng loc) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return "${place.locality}, ${place.country}";
      }
    } catch (e) {
      debugPrint("Reverse geocoding failed: $e");
    }
    return "Unknown location";
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
            snippet: [
              if (inAt != null) DateFormat.jm().format(inAt!),
              if (inAddress != null) inAddress!,
            ].join("\n"),
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
            snippet: [
              if (outAt != null) DateFormat.jm().format(outAt!),
              if (outAddress != null) outAddress!,
            ].join("\n"),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    CameraPosition initialCam = const CameraPosition(
      target: LatLng(18.005611, -76.744127),
      zoom: 15,
    );
    if (_inLoc != null) {
      initialCam = CameraPosition(target: _inLoc!, zoom: 18);
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Expanded(
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
          ),
          const Divider(height: 1),
          // 👇 Info section under the map
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_inLoc != null) ...[
                  Text(
                    "Clock In",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    inAt != null
                        ? "Time: ${DateFormat.jm().format(inAt!)}"
                        : "Time: Unknown",
                  ),
                  Text("Location: ${inAddress ?? "Fetching..."}"),
                  const SizedBox(height: 8),
                ],
                if (_outLoc != null) ...[
                  Text(
                    "Clock Out",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    outAt != null
                        ? "Time: ${DateFormat.jm().format(outAt!)}"
                        : "Time: Unknown",
                  ),
                  Text("Location: ${outAddress ?? "Fetching..."}"),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
