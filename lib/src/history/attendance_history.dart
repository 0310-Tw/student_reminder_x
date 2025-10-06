// import 'dart:async';
// import 'package:flutter/foundation.dart' show debugPrint;
// import 'package:flutter/material.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:intl/intl.dart';
// import 'package:students_reminder/src/history/shift_timeline.dart';
// import 'package:students_reminder/src/services/attendance_service.dart';
// import 'package:students_reminder/src/services/auth_service.dart';
// import 'package:students_reminder/src/shared/misc.dart';
// import 'package:students_reminder/src/widgets/suspension_check.dart';

// class AttendanceHistory14d extends StatefulWidget {
//   const AttendanceHistory14d({super.key});

//   @override
//   State<AttendanceHistory14d> createState() => _AttendanceHistory14dState();
// }

// class _AttendanceHistory14dState extends State<AttendanceHistory14d> {
//   bool _showCalendar = false;
//   bool _isClockedIn = false;
//   StreamSubscription<Position>? _locationSub;
//   Timer? _autoClockOutTimer;

//   @override
//   void initState() {
//     super.initState();
//     _loadTodayClockStatus();
//     _scheduleAutoClockOut();
//   }

//   @override
//   void dispose() {
//     _locationSub?.cancel();
//     _autoClockOutTimer?.cancel();
//     super.dispose();
//   }

//   Future<void> _loadTodayClockStatus() async {
//     final currentUser = AuthService.instance.currentUser;
//     if (currentUser == null) return;

//     final uid = currentUser.uid;
//     final todayDoc = await FirebaseFirestore.instance
//         .collection('attendance')
//         .doc(uid)
//         .collection('days')
//         .doc(JmTime.dateId(DateTime.now()))
//         .get();

//     if (!mounted) return;

//     setState(() {
//       _isClockedIn =
//           todayDoc.exists &&
//           todayDoc.data()?['inAt'] != null &&
//           todayDoc.data()?['outAt'] == null;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final currentUser = AuthService.instance.currentUser;

//     if (currentUser == null) {
//       return const Scaffold(
//         body: Center(child: Text('Please log in to view attendance')),
//       );
//     }

//     final uid = currentUser.uid;
//     final now = JmTime.nowLocal();
//     final end = DateTime(now.year, now.month, now.day);

//     return Scaffold(
//       backgroundColor: const Color(0xFFF7F9FC),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF2C3E50),
//         foregroundColor: Colors.white,
//         automaticallyImplyLeading: false,
//         title: const Text('Attendance • Last 14 days'),
//         actions: [
//           IconButton(
//             tooltip: _showCalendar ? 'Show list' : 'Show calendar',
//             onPressed: () => setState(() => _showCalendar = !_showCalendar),
//             icon: Icon(_showCalendar ? Icons.view_list : Icons.calendar_month),
//           ),
//         ],
//       ),
//       body: SuspensionCheck(
//         child: Column(
//           children: [
//             // Single dynamic Clock In / Clock Out button
//             Padding(
//               padding: const EdgeInsets.all(8),
//               child: ElevatedButton.icon(
//                 onPressed: () async {
//                   if (_isClockedIn) {
//                     await _clockOut(uid);
//                   } else {
//                     await _clockIn(uid);
//                   }
//                   await _loadTodayClockStatus();
//                 },
//                 icon: Icon(_isClockedIn ? Icons.logout : Icons.login, size: 16),
//                 label: Text(
//                   _isClockedIn ? "Clock Out" : "Clock In",
//                   style: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _isClockedIn
//                       ? const Color(0xFFE74C3C)
//                       : const Color(0xFF3498DB),
//                   foregroundColor: Colors.white,
//                   minimumSize: const Size(double.infinity, 48),
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 12,
//                   ),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   elevation: 2,
//                 ),
//               ),
//             ),
//             Expanded(
//               child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//                 stream: AttendanceService.streamLast14Days(uid),
//                 builder: (context, snap) {
//                   if (snap.connectionState == ConnectionState.waiting) {
//                     return Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: const [
//                           CircularProgressIndicator(),
//                           SizedBox(height: 16),
//                           Text(
//                             'Loading attendance data...',
//                             style: TextStyle(fontSize: 16, color: Colors.grey),
//                           ),
//                         ],
//                       ),
//                     );
//                   }

//                   if (snap.connectionState == ConnectionState.none) {
//                     return Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.wifi_off,
//                             size: 64,
//                             color: Colors.grey[400],
//                           ),
//                           const SizedBox(height: 16),
//                           const Text(
//                             'No connection',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           const Text(
//                             'Please check your internet connection',
//                             style: TextStyle(fontSize: 14, color: Colors.grey),
//                           ),
//                         ],
//                       ),
//                     );
//                   }

//                   if (snap.hasError) {
//                     return Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.error_outline,
//                             size: 64,
//                             color: Colors.red[400],
//                           ),
//                           const SizedBox(height: 16),
//                           const Text(
//                             'Error loading attendance data',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             'Error: ${snap.error}',
//                             style: TextStyle(
//                               fontSize: 14,
//                               color: Colors.grey[600],
//                             ),
//                             textAlign: TextAlign.center,
//                           ),
//                           const SizedBox(height: 16),
//                           ElevatedButton(
//                             onPressed: () => setState(() {}),
//                             child: const Text('Retry'),
//                           ),
//                         ],
//                       ),
//                     );
//                   }

//                   final docs =
//                       snap.data?.docs ??
//                       <QueryDocumentSnapshot<Map<String, dynamic>>>[];
//                   final byDate = {
//                     for (final d in docs)
//                       (d.data()['dayId'] as String): d.data(),
//                   };

//                   final items = <_DayItem>[];
//                   for (int i = 13; i >= 0; i--) {
//                     final day = end.subtract(Duration(days: i));
//                     final id = JmTime.dateId(day);
//                     items.add(
//                       _DayItem(date: day, dateId: id, data: byDate[id]),
//                     );
//                   }

//                   return _showCalendar
//                       ? _CalendarGrid(uid: uid, days: items)
//                       : _HistoryList(uid: uid, days: items);
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ------------------ Clock In ------------------
//   Future<void> _clockIn(String uid) async {
//     final now = DateTime.now();
//     final eightAM = DateTime(now.year, now.month, now.day, 8, 0);
//     final eightThirty = DateTime(now.year, now.month, now.day, 8, 30);

//     Position? location;
//     try {
//       location = await _getLocation();
//     } catch (e) {
//       _showSnack("Location error: $e");
//       return;
//     }

//     String status;
//     String? reason;
//     if (now.isBefore(eightAM)) {
//       _showSnack("Too early to clock in. Please wait until 8:00 AM.");
//       return;
//     } else if (now.isAfter(eightAM) && now.isBefore(eightThirty)) {
//       status = "present"; // On time or early
//     } else if (now.isAfter(eightThirty) &&
//         now.isBefore(DateTime(now.year, now.month, now.day, 16))) {
//       status = "late";
//       reason = await _askLateReason();
//       if (reason == null || reason.trim().isEmpty) {
//         _showSnack("Late reason required.");
//         return;
//       }
//     } else {
//       _showSnack("Too late to clock in.");
//       return;
//     }

//     // Get place name for better user experience
//     final placeName = await _getPlaceName(location);

//     final attendanceData = {
//       'dayId': JmTime.dateId(now),
//       'inAt': Timestamp.fromDate(now),
//       'inLoc': GeoPoint(location.latitude, location.longitude),
//       'placeIn': placeName,
//       'status': status,
//     };

//     if (reason != null && reason.trim().isNotEmpty) {
//       attendanceData['lateReason'] = reason.trim();
//     }

//     await FirebaseFirestore.instance
//         .collection('attendance')
//         .doc(uid)
//         .collection('days')
//         .doc(JmTime.dateId(now))
//         .set(attendanceData, SetOptions(merge: true));

//     // Start live location tracking
//     await _startLiveTracking(uid);

//     // Reschedule auto clock-out after clock-in
//     _scheduleAutoClockOut();

//     final displayMessage = reason != null && reason.trim().isNotEmpty
//         ? "Clocked in: $status (Reason: $reason) at $placeName"
//         : "Clocked in: $status at $placeName";

//     _showSnack(displayMessage);
//   }

//   // ------------------ Clock Out ------------------
//   Future<void> _clockOut(String uid) async {
//     final now = DateTime.now();

//     Position? location;
//     try {
//       location = await _getLocation();
//     } catch (e) {
//       _showSnack("Location error: $e");
//       return;
//     }

//     final dayDoc = FirebaseFirestore.instance
//         .collection('attendance')
//         .doc(uid)
//         .collection('days')
//         .doc(JmTime.dateId(now));

//     final snapshot = await dayDoc.get();
//     if (!snapshot.exists || snapshot.data()?['inAt'] == null) {
//       _showSnack("Cannot clock out before clocking in.");
//       return;
//     }

//     final existingData = snapshot.data();
//     final currentStatus = existingData?['status'] ?? 'present';

//     // Get place name for better user experience
//     final placeName = await _getPlaceName(location);

//     // Maintain the original status (present/late) when clocking out
//     await dayDoc.set({
//       'outAt': Timestamp.fromDate(now),
//       'outLoc': GeoPoint(location.latitude, location.longitude),
//       'placeOut': placeName,
//       'status': currentStatus, // Keep the original clock-in status
//     }, SetOptions(merge: true));

//     // Stop live location tracking
//     await _stopLiveTracking();

//     // Cancel auto clock-out timer
//     _autoClockOutTimer?.cancel();

//     _showSnack("Clocked out successfully at $placeName");
//   }

//   Future<Position> _getLocation() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) throw 'Location services disabled';

//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied ||
//         permission == LocationPermission.deniedForever) {
//       permission = await Geolocator.requestPermission();
//       if (permission != LocationPermission.whileInUse &&
//           permission != LocationPermission.always) {
//         throw 'Location permission denied';
//       }
//     }

//     return await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//   }

//   Future<String?> _askLateReason() async {
//     String reason = '';
//     return showDialog<String>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Late Reason'),
//         content: TextField(
//           autofocus: true,
//           onChanged: (value) => reason = value,
//           decoration: const InputDecoration(hintText: 'Why are you late?'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(ctx, reason),
//             child: const Text('Submit'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showSnack(String msg) {
//     displaySnackBar(context, msg);
//   }

//   // ------------------ Auto Clock Out ------------------
//   void _scheduleAutoClockOut() {
//     _autoClockOutTimer?.cancel();

//     final now = DateTime.now();
//     final clockOutTime = DateTime(now.year, now.month, now.day, 16, 0); // 4 PM
//     Duration durationUntil4PM = clockOutTime.difference(now);

//     if (durationUntil4PM.isNegative) {
//       // Already past 4 PM today, no timer needed
//       return;
//     }

//     _autoClockOutTimer = Timer(durationUntil4PM, () async {
//       final currentUser = AuthService.instance.currentUser;
//       if (currentUser != null && _isClockedIn) {
//         await _clockOut(currentUser.uid);
//         await _loadTodayClockStatus();
//         _showSnack("Automatically clocked out at 4:00 PM");
//       }
//     });
//   }

//   // ------------------ Live Location Tracking ------------------
//   Future<void> _startLiveTracking(String uid) async {
//     _locationSub?.cancel();
//     _locationSub =
//         Geolocator.getPositionStream(
//           locationSettings: const LocationSettings(
//             accuracy: LocationAccuracy.high,
//             distanceFilter: 10, // Update every 10 meters
//           ),
//         ).listen((pos) async {
//           final placeName = await _getPlaceName(pos);
//           await _updateLiveLocation(uid, pos, placeName);
//         });
//   }

//   Future<void> _stopLiveTracking() async {
//     await _locationSub?.cancel();
//     _locationSub = null;
//   }

//   Future<void> _updateLiveLocation(
//     String uid,
//     Position pos,
//     String placeName,
//   ) async {
//     final now = DateTime.now();
//     final dayId = JmTime.dateId(now);

//     await FirebaseFirestore.instance
//         .collection('attendance')
//         .doc(uid)
//         .collection('days')
//         .doc(dayId)
//         .set({
//           'liveLat': pos.latitude,
//           'liveLng': pos.longitude,
//           'livePlace': placeName,
//           'liveUpdated': Timestamp.now(),
//         }, SetOptions(merge: true));
//   }

//   Future<String> _getPlaceName(Position pos) async {
//     try {
//       final placemarks = await placemarkFromCoordinates(
//         pos.latitude,
//         pos.longitude,
//       );
//       if (placemarks.isNotEmpty) {
//         final p = placemarks.first;
//         return "${p.name ?? ''}, ${p.locality ?? ''}".trim();
//       }
//     } catch (_) {}
//     return "Unknown location";
//   }
// }

// // ------------------ Models + Helpers ------------------

// class _DayItem {
//   final DateTime date;
//   final String dateId;
//   final Map<String, dynamic>? data;
//   _DayItem({required this.date, required this.dateId, required this.data});

//   String get rawStatus => (data?['status'] ?? 'absent').toString();

//   String get status {
//     // If there's no data for this day, it's absent
//     if (data == null) return 'absent';

//     // Check if user clocked in
//     final clockedIn = data!['inAt'] != null;

//     if (!clockedIn) return 'absent';

//     // Use the stored status from clock-in
//     final storedStatus = rawStatus.toLowerCase();
//     if (storedStatus.contains('late')) return 'late';
//     if (storedStatus.contains('present') || storedStatus.contains('early'))
//       return 'present';

//     // Default to present if they have clocked in
//     return clockedIn ? 'present' : 'absent';
//   }

//   String? get reason {
//     if (rawStatus.contains('— Reason:')) {
//       return rawStatus.split('— Reason:')[1].trim();
//     }
//     return data?['lateReason'] as String?;
//   }

//   DateTime? get inAt {
//     final timestamp = data?['inAt'] ?? data?['clockInAt'];
//     return (timestamp as Timestamp?)?.toDate();
//   }

//   DateTime? get outAt {
//     final timestamp = data?['outAt'] ?? data?['clockOutAt'];
//     return (timestamp as Timestamp?)?.toDate();
//   }

//   bool get isAdminMarked => data?['adminMarked'] == true;
//   String? get markedByAdminName => data?['markedByAdminName'] as String?;
//   String? get markedByAdminEmail => data?['markedByAdminEmail'] as String?;
//   DateTime? get markedAt => (data?['markedAt'] as Timestamp?)?.toDate();
// }

// Color _statusColor(String status) {
//   switch (status) {
//     case 'present':
//       return Color(0xFF27AE60); // Sage Green
//     case 'early':
//       return Color(0xFF27AE60); // Sage Green
//     case 'late':
//       return Color(0xFFF39C12); // Warm Amber
//     case 'absent':
//     default:
//       return Color(0xFFE74C3C); // Soft Red
//   }
// }

// Widget _statusBadgeWithAdmin(_DayItem dayItem) {
//   final status = dayItem.status;
//   final reason = dayItem.reason;
//   final c = _statusColor(status);

//   String displayText = status.toUpperCase();
//   if (reason != null && reason.isNotEmpty) {
//     displayText += '\n$reason';
//   }

//   if (dayItem.isAdminMarked) {
//     displayText += '\n👤Admin';
//     if (dayItem.markedByAdminName != null) {
//       displayText += ': ${dayItem.markedByAdminName}';
//     }
//   }

//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//     decoration: BoxDecoration(
//       color: c.withOpacity(0.12),
//       border: Border.all(
//         color: dayItem.isAdminMarked
//             ? Color(0xFF8E44AD).withOpacity(0.8)
//             : c.withOpacity(0.6),
//         width: dayItem.isAdminMarked ? 2 : 1,
//       ),
//       borderRadius: BorderRadius.circular(999),
//     ),
//     child: Text(
//       displayText,
//       style: TextStyle(
//         fontSize: 10,
//         fontWeight: FontWeight.w600,
//         color: dayItem.isAdminMarked ? Color(0xFF8E44AD) : c,
//       ),
//       textAlign: TextAlign.center,
//     ),
//   );
// }

// // ignore: unused_element
// Widget _statusChip(String status, [String? reason]) {
//   Color c;
//   String label = status.toUpperCase();
//   switch (status.toLowerCase()) {
//     case 'early':
//       c = Colors.green;
//       break;
//     case 'late':
//       c = Colors.orange;
//       break;
//     case 'absent':
//     default:
//       c = Colors.red;
//       label = 'ABSENT';
//   }
//   if (reason != null) label += '\n$reason';
//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//     decoration: BoxDecoration(
//       color: c.withOpacity(0.12),
//       border: Border.all(color: c.withOpacity(0.6)),
//       borderRadius: BorderRadius.circular(999),
//     ),
//     child: Text(
//       label,
//       style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
//       textAlign: TextAlign.center,
//     ),
//   );
// }

// String _fmtJM(DateTime? t) => t == null ? '—' : DateFormat.jm().format(t);

// // ------------------ List View ------------------

// class _HistoryList extends StatelessWidget {
//   const _HistoryList({required this.uid, required this.days});
//   final String uid;
//   final List<_DayItem> days;

//   // ✅ Status color helper
//   Color _statusColor(String status) {
//     switch (status) {
//       case 'Early':
//         return Colors.green;
//       case 'Late':
//         return Colors.orange;
//       case 'Absent':
//         return Colors.red;
//       default:
//         return Colors.grey;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ListView.separated(
//       itemCount: days.length,
//       separatorBuilder: (_, __) => const Divider(height: 1),
//       itemBuilder: (context, i) {
//         final d = days[i];
//         final dateLabel = DateFormat('EEE, MMM d').format(d.date);

//         return ListTile(
//           title: Text(dateLabel),
//           subtitle: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               if (d.inAt != null)
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'In: ${_fmtJM(d.inAt)}',
//                       style: const TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     if (d.data?['placeIn'] != null)
//                       Text(
//                         d.data!['placeIn'],
//                         style: TextStyle(
//                           color: Colors.grey.shade600,
//                           fontSize: 12,
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                   ],
//                 ),
//               if (d.outAt != null)
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Out: ${_fmtJM(d.outAt)}',
//                       style: const TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     if (d.data?['placeOut'] != null)
//                       Text(
//                         d.data!['placeOut'],
//                         style: TextStyle(
//                           color: Colors.grey.shade600,
//                           fontSize: 12,
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                   ],
//                 ),
//               if (d.data?['livePlace'] != null)
//                 Text(
//                   'Live: ${d.data!['livePlace']}',
//                   style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               const SizedBox(height: 6),
//               // Shift timeline with status color
//               SizedBox(
//                 height: 20,
//                 child: ShiftTimeline(
//                   clockIn: d.inAt,
//                   clockOut: d.outAt,
//                   color: _statusColor(d.status), // Use status color
//                 ),
//               ),
//             ],
//           ),
//           trailing: _statusBadgeWithAdmin(d),
//           onTap: () => _openMapModal(context, uid: uid, dayId: d.dateId),
//         );
//       },
//     );
//   }
// }

// // ------------------ Calendar Grid ------------------

// class _CalendarGrid extends StatelessWidget {
//   const _CalendarGrid({required this.uid, required this.days});
//   final String uid;
//   final List<_DayItem> days;

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(12),
//       child: Column(
//         children: [
//           // Legend
//           Wrap(
//             spacing: 12,
//             runSpacing: 8,
//             children: const [
//               _Legend(color: Color(0xFF27AE60), label: 'Present'),
//               _Legend(color: Color(0xFFF39C12), label: 'Late'),
//               _Legend(color: Color(0xFFE74C3C), label: 'Absent'),
//             ],
//           ),
//           const SizedBox(height: 12),
//           // Grid
//           Expanded(
//             child: GridView.builder(
//               itemCount: days.length,
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 7,
//                 mainAxisSpacing: 10,
//                 crossAxisSpacing: 10,
//                 childAspectRatio: 0.8, // Adjusted for better spacing
//               ),
//               itemBuilder: (context, i) {
//                 final d = days[i];
//                 final dot = _statusColor(d.status);

//                 return InkWell(
//                   onTap: () =>
//                       _openMapModal(context, uid: uid, dayId: d.dateId),
//                   child: Container(
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: Theme.of(context).dividerColor),
//                     ),
//                     padding: const EdgeInsets.all(8),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         // Day number
//                         Text(
//                           DateFormat('d').format(d.date),
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                         const SizedBox(height: 6),
//                         // Status dot with mini timeline inside
//                         SizedBox(
//                           width: 16,
//                           height: 16,
//                           child: Stack(
//                             alignment: Alignment.center,
//                             children: [
//                               // Background circle (lighter)
//                               Container(
//                                 width: 12,
//                                 height: 12,
//                                 decoration: BoxDecoration(
//                                   color: dot.withOpacity(0.3),
//                                   shape: BoxShape.circle,
//                                 ),
//                               ),
//                               // Mini timeline bar
//                               FractionallySizedBox(
//                                 widthFactor: d.inAt != null && d.outAt != null
//                                     ? 1.0
//                                     : 0.0,
//                                 heightFactor: 0.3,
//                                 child: Container(
//                                   decoration: BoxDecoration(
//                                     color: dot,
//                                     borderRadius: BorderRadius.circular(2),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _Legend extends StatelessWidget {
//   const _Legend({required this.color, required this.label});
//   final Color color;
//   final String label;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 10,
//           height: 10,
//           decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//         ),
//         const SizedBox(width: 6),
//         Text(label, style: const TextStyle(fontSize: 12)),
//       ],
//     );
//   }
// }

// // ------------------ Map Modal ------------------

// void _openMapModal(
//   BuildContext context, {
//   required String uid,
//   required String dayId,
// }) {
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     shape: const RoundedRectangleBorder(
//       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//     ),
//     builder: (_) => DayMapModal(uid: uid, dayId: dayId),
//   );
// }

// class DayMapModal extends StatefulWidget {
//   const DayMapModal({super.key, required this.uid, required this.dayId});
//   final String uid;
//   final String dayId;

//   @override
//   State<DayMapModal> createState() => _DayMapModalState();
// }

// class _DayMapModalState extends State<DayMapModal> {
//   LatLng? _inLoc;
//   LatLng? _outLoc;
//   LatLng? _liveLoc;
//   String status = 'absent';
//   DateTime? inAt;
//   DateTime? outAt;

//   String? inAddress;
//   String? outAddress;
//   String? inPlace;
//   String? outPlace;
//   String? livePlace;

//   @override
//   void initState() {
//     super.initState();
//     _loadAttendance();
//   }

//   Future<void> _loadAttendance() async {
//     final ref = FirebaseFirestore.instance
//         .collection('attendance')
//         .doc(widget.uid)
//         .collection('days')
//         .doc(widget.dayId);
//     final snap = await ref.get();
//     if (!mounted) return;

//     final data = snap.data();
//     if (data != null) {
//       final inTimestamp = data['inAt'] ?? data['clockInAt'];
//       final outTimestamp = data['outAt'] ?? data['clockOutAt'];

//       _inLoc = _toLatLng(data['inLoc'] ?? data['clockInLoc']);
//       _outLoc = _toLatLng(data['outLoc'] ?? data['clockOutLoc']);

//       // Add live location support
//       _liveLoc = (data['liveLat'] != null && data['liveLng'] != null)
//           ? LatLng(data['liveLat'], data['liveLng'])
//           : null;

//       inAt = (inTimestamp as Timestamp?)?.toDate();
//       outAt = (outTimestamp as Timestamp?)?.toDate();
//       status = (data['status'] ?? 'absent').toString();

//       // Get place names from stored data
//       inPlace = data['placeIn'] as String?;
//       outPlace = data['placeOut'] as String?;
//       livePlace = data['livePlace'] as String?;

//       // Trigger initial UI update with location data
//       if (mounted) setState(() {});

//       // Load addresses in background for fallback
//       if (_inLoc != null && inPlace == null) {
//         inAddress = await _reverseGeocode(_inLoc!);
//       }
//       if (_outLoc != null && outPlace == null) {
//         outAddress = await _reverseGeocode(_outLoc!);
//       }

//       // Final UI update with addresses
//       if (mounted) setState(() {});
//     }
//   }

//   LatLng? _toLatLng(dynamic v) {
//     if (v == null) return null;
//     if (v is GeoPoint) return LatLng(v.latitude, v.longitude);
//     return null;
//   }

//   Future<String?> _reverseGeocode(LatLng pos) async {
//     try {
//       final placemarks = await placemarkFromCoordinates(
//         pos.latitude,
//         pos.longitude,
//       );
//       if (placemarks.isNotEmpty) {
//         final pm = placemarks.first;
//         return "${pm.street}, ${pm.locality}, ${pm.country}";
//       }
//     } catch (_) {}
//     return null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final markers = <Marker>{};

//     // Add Clock In marker with green color
//     if (_inLoc != null) {
//       markers.add(
//         Marker(
//           markerId: const MarkerId("clock_in"),
//           position: _inLoc!,
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueGreen,
//           ),
//           infoWindow: InfoWindow(
//             title: "Clock In Location",
//             snippet: inAt != null
//                 ? "Time: ${_fmtJM(inAt)}\n${inPlace ?? inAddress ?? 'Loading address...'}"
//                 : "Loading...",
//           ),
//           consumeTapEvents: true,
//         ),
//       );
//     }

//     // Add Clock Out marker with red color
//     if (_outLoc != null) {
//       markers.add(
//         Marker(
//           markerId: const MarkerId("clock_out"),
//           position: _outLoc!,
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//           infoWindow: InfoWindow(
//             title: "Clock Out Location",
//             snippet: outAt != null
//                 ? "Time: ${_fmtJM(outAt)}\n${outPlace ?? outAddress ?? 'Loading address...'}"
//                 : "Loading...",
//           ),
//           consumeTapEvents: true,
//         ),
//       );
//     }

//     // Add Live Location marker with blue color
//     if (_liveLoc != null) {
//       markers.add(
//         Marker(
//           markerId: const MarkerId("live_location"),
//           position: _liveLoc!,
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueAzure,
//           ),
//           infoWindow: InfoWindow(
//             title: "Live Location",
//             snippet: livePlace ?? 'Current location',
//           ),
//           consumeTapEvents: true,
//         ),
//       );
//     }

//     // Use the most recent location as center, prioritizing live location
//     final center =
//         _liveLoc ?? _outLoc ?? _inLoc ?? const LatLng(18.0179, -76.8099);

//     // Calculate initial zoom based on available locations
//     double initialZoom = 12.0;
//     if (_inLoc != null && (_outLoc != null || _liveLoc != null)) {
//       // If we have multiple locations, use a wider zoom to fit both
//       initialZoom = 11.0;
//     } else if (_inLoc != null || _outLoc != null || _liveLoc != null) {
//       // If we have one location, use a medium zoom
//       initialZoom = 12.5;
//     }

//     return DraggableScrollableSheet(
//       expand: false,
//       minChildSize: 0.5,
//       initialChildSize: 0.75,
//       builder: (context, scrollController) {
//         return Column(
//           children: [
//             Container(
//               height: 5,
//               width: 40,
//               margin: const EdgeInsets.symmetric(vertical: 12),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade400,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//             Text(
//               "Day: ${widget.dayId}",
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             Text("Status: $status"),
//             if (inAt != null)
//               Text(
//                 "Clock In: ${_fmtJM(inAt)}${inPlace != null ? ' • $inPlace' : ''}",
//               ),
//             if (outAt != null)
//               Text(
//                 "Clock Out: ${_fmtJM(outAt)}${outPlace != null ? ' • $outPlace' : ''}",
//               ),
//             if (_liveLoc != null)
//               Text("Live: ${livePlace ?? 'Current location'}"),
//             const SizedBox(height: 12),
//             Expanded(
//               child: Container(
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: Colors.grey.shade300),
//                 ),
//                 clipBehavior: Clip.hardEdge,
//                 child: GoogleMap(
//                   key: ValueKey("map_${widget.dayId}_${markers.length}"),
//                   initialCameraPosition: CameraPosition(
//                     target: center,
//                     zoom: initialZoom,
//                   ),
//                   onMapCreated: (GoogleMapController controller) async {
//                     try {
//                       // Add a longer delay to ensure map is fully initialized
//                       await Future.delayed(const Duration(milliseconds: 1000));

//                       // Check if widget is still mounted before camera operations
//                       if (!mounted) return;

//                       // Try to animate camera with multiple fallback strategies
//                       if (_inLoc != null && _outLoc != null) {
//                         // Strategy 1: Try bounds fitting
//                         try {
//                           final bounds = LatLngBounds(
//                             southwest: LatLng(
//                               _inLoc!.latitude < _outLoc!.latitude
//                                   ? _inLoc!.latitude
//                                   : _outLoc!.latitude,
//                               _inLoc!.longitude < _outLoc!.longitude
//                                   ? _inLoc!.longitude
//                                   : _outLoc!.longitude,
//                             ),
//                             northeast: LatLng(
//                               _inLoc!.latitude > _outLoc!.latitude
//                                   ? _inLoc!.latitude
//                                   : _outLoc!.latitude,
//                               _inLoc!.longitude > _outLoc!.longitude
//                                   ? _inLoc!.longitude
//                                   : _outLoc!.longitude,
//                             ),
//                           );
//                           await controller.animateCamera(
//                             CameraUpdate.newLatLngBounds(bounds, 100),
//                           );
//                         } catch (boundsError) {
//                           // Fallback: Just zoom to the most recent location
//                           debugPrint(
//                             'Bounds camera animation failed: $boundsError',
//                           );
//                           await controller.animateCamera(
//                             CameraUpdate.newLatLngZoom(_outLoc!, 12),
//                           );
//                         }
//                       } else if (_inLoc != null) {
//                         // If only clock-in location, zoom to it
//                         await controller.animateCamera(
//                           CameraUpdate.newLatLngZoom(_inLoc!, 12.5),
//                         );
//                       } else if (_outLoc != null) {
//                         // If only clock-out location, zoom to it
//                         await controller.animateCamera(
//                           CameraUpdate.newLatLngZoom(_outLoc!, 12.5),
//                         );
//                       }
//                     } catch (e) {
//                       // Silently handle camera animation errors
//                       debugPrint('Map camera animation error: $e');
//                     }
//                   },
//                   markers: Set<Marker>.from(markers),
//                   mapType: MapType.normal,
//                   myLocationEnabled:
//                       false, // Disable to avoid permission issues
//                   myLocationButtonEnabled: false,
//                   zoomControlsEnabled: true,
//                   compassEnabled: true,
//                   buildingsEnabled: true,
//                   trafficEnabled: false,
//                   mapToolbarEnabled: false,
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:students_reminder/src/history/shift_timeline.dart';
import 'package:students_reminder/src/services/attendance_service.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/helper.dart';
import 'package:students_reminder/src/shared/misc.dart';
import 'package:students_reminder/src/widgets/atrisk_banner_notifications.dart';
import 'package:students_reminder/src/widgets/suspension_check.dart';

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
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return;

    final uid = currentUser.uid;
    final todayDoc = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .doc(JmTime.dateId(DateTime.now()))
        .get();

    if (!mounted) return;

    setState(() {
      _isClockedIn =
          todayDoc.exists &&
          todayDoc.data()?['inAt'] != null &&
          todayDoc.data()?['outAt'] == null;
    });
  }

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
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
          child: Column(
            children: [
              AtRiskBannerNotifications(),
              // Single dynamic Clock In / Clock Out button
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isClockedIn
                        ? const Color(0xFFE74C3C)
                        : const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: AttendanceService.streamLast14Days(uid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Loading attendance data...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snap.connectionState == ConnectionState.none) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wifi_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No connection',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please check your internet connection',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snap.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Error loading attendance data',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Error: ${snap.error}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => setState(() {}),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/student-geofence-dashboard');
        },
        icon: Icon(Icons.location_on),
        label: Text('Geofencing'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        tooltip: 'Set up your geofencing locations',
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
    if (now.isBefore(eightAM)) {
      _showSnack("Too early to clock in. Please wait until 8:00 AM.");
      return;
    } else if (now.isAfter(eightAM) && now.isBefore(eightThirty)) {
      status = "present"; // On time or early
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

    // Get place name for better user experience
    final placeName = await _getPlaceName(location);

    // Validate geofence before proceeding with clock-in
    final dateId = JmTime.dateId(now);
    final canProceed = await handleClockAction(
      context: context,
      studentId: uid,
      dateId: dateId,
      actionType: 'checkin',
    );

    if (!canProceed) {
      _showSnack("Clock In blocked - outside designated area");
      return;
    }

    final attendanceData = {
      'dayId': dateId,
      'inAt': Timestamp.fromDate(now),
      'inLoc': GeoPoint(location.latitude, location.longitude),
      'placeIn': placeName,
      'status': status,
    };

    if (reason != null && reason.trim().isNotEmpty) {
      attendanceData['lateReason'] = reason.trim();
    }

    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(uid)
        .collection('days')
        .doc(dateId)
        .set(attendanceData, SetOptions(merge: true));

    // Start live location tracking
    await _startLiveTracking(uid);

    // Reschedule auto clock-out after clock-in
    _scheduleAutoClockOut();

    final displayMessage = reason != null && reason.trim().isNotEmpty
        ? "Clocked in: $status (Reason: $reason) at $placeName"
        : "Clocked in: $status at $placeName";

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

    final existingData = snapshot.data();
    final currentStatus = existingData?['status'] ?? 'present';

    // Get place name for better user experience
    final placeName = await _getPlaceName(location);

    // Validate geofence before proceeding with clock-out
    final dateId = JmTime.dateId(now);
    final canProceed = await handleClockAction(
      context: context,
      studentId: uid,
      dateId: dateId,
      actionType: 'checkout',
    );

    if (!canProceed) {
      _showSnack("Clock Out blocked - outside designated area");
      return;
    }

    // Maintain the original status (present/late) when clocking out
    await dayDoc.set({
      'outAt': Timestamp.fromDate(now),
      'outLoc': GeoPoint(location.latitude, location.longitude),
      'placeOut': placeName,
      'status': currentStatus, // Keep the original clock-in status
    }, SetOptions(merge: true));

    // Stop live location tracking
    await _stopLiveTracking();

    // Cancel auto clock-out timer
    _autoClockOutTimer?.cancel();

    _showSnack("Clocked out successfully at $placeName");
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

  // ------------------ Auto Clock Out ------------------
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
      if (currentUser != null && _isClockedIn) {
        await _clockOut(currentUser.uid);
        await _loadTodayClockStatus();
        _showSnack("Automatically clocked out at 4:00 PM");
      }
    });
  }

  // ------------------ Live Location Tracking ------------------
  Future<void> _startLiveTracking(String uid) async {
    _locationSub?.cancel();
    _locationSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Update every 10 meters
          ),
        ).listen((pos) async {
          final placeName = await _getPlaceName(pos);
          await _updateLiveLocation(uid, pos, placeName);
        });
  }

  Future<void> _stopLiveTracking() async {
    await _locationSub?.cancel();
    _locationSub = null;
  }

  Future<void> _updateLiveLocation(
    String uid,
    Position pos,
    String placeName,
  ) async {
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
          'livePlace': placeName,
          'liveUpdated': Timestamp.now(),
        }, SetOptions(merge: true));
  }

  Future<String> _getPlaceName(Position pos) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return "${p.name ?? ''}, ${p.locality ?? ''}".trim();
      }
    } catch (_) {}
    return "Unknown location";
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
    // If there's no data for this day, it's absent
    if (data == null) return 'absent';

    // Check if user clocked in
    final clockedIn = data!['inAt'] != null;

    if (!clockedIn) return 'absent';

    // Use the stored status from clock-in
    final storedStatus = rawStatus.toLowerCase();
    if (storedStatus.contains('late')) return 'late';
    if (storedStatus.contains('present') || storedStatus.contains('early'))
      return 'present';

    // Default to present if they have clocked in
    return clockedIn ? 'present' : 'absent';
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
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
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
              // Enhanced UI with icons from shanakay-ui-v1
              Row(
                children: [
                  if (d.inAt != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.login,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text('In: ${_fmtJM(d.inAt)}'),
                            ],
                          ),
                          if (d.data?['placeIn'] != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: Text(
                                d.data!['placeIn'],
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (d.outAt != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.logout,
                                size: 16,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text('Out: ${_fmtJM(d.outAt)}'),
                            ],
                          ),
                          if (d.data?['placeOut'] != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: Text(
                                d.data!['placeOut'],
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              if (d.data?['livePlace'] != null)
                Text(
                  'Live: ${d.data!['livePlace']}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
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
              _Legend(color: Color(0xFF27AE60), label: 'Present'),
              _Legend(color: Color(0xFFF39C12), label: 'Late'),
              _Legend(color: Color(0xFFE74C3C), label: 'Absent'),
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
                  onTap: () =>
                      _openMapModal(context, uid: uid, dayId: d.dateId),
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
                                widthFactor: d.inAt != null && d.outAt != null
                                    ? 1.0
                                    : 0.0,
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

void _openMapModal(
  BuildContext context, {
  required String uid,
  required String dayId,
}) {
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
  LatLng? _inLoc;
  LatLng? _outLoc;
  LatLng? _liveLoc;
  String status = 'absent';
  DateTime? inAt;
  DateTime? outAt;

  String? inAddress;
  String? outAddress;
  String? inPlace;
  String? outPlace;
  String? livePlace;

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

      // Add live location support
      _liveLoc = (data['liveLat'] != null && data['liveLng'] != null)
          ? LatLng(data['liveLat'], data['liveLng'])
          : null;

      inAt = (inTimestamp as Timestamp?)?.toDate();
      outAt = (outTimestamp as Timestamp?)?.toDate();
      status = (data['status'] ?? 'absent').toString();

      // Get place names from stored data
      inPlace = data['placeIn'] as String?;
      outPlace = data['placeOut'] as String?;
      livePlace = data['livePlace'] as String?;

      // Trigger initial UI update with location data
      if (mounted) setState(() {});

      // Load addresses in background for fallback
      if (_inLoc != null && inPlace == null) {
        inAddress = await _reverseGeocode(_inLoc!);
      }
      if (_outLoc != null && outPlace == null) {
        outAddress = await _reverseGeocode(_outLoc!);
      }

      // Final UI update with addresses
      if (mounted) setState(() {});
    }
  }

  LatLng? _toLatLng(dynamic v) {
    if (v == null) return null;
    if (v is GeoPoint) return LatLng(v.latitude, v.longitude);
    return null;
  }

  Future<String?> _reverseGeocode(LatLng pos) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
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

    // Add Clock In marker with green color
    if (_inLoc != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("clock_in"),
          position: _inLoc!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: "Clock In Location",
            snippet: inAt != null
                ? "Time: ${_fmtJM(inAt)}\n${inPlace ?? inAddress ?? 'Loading address...'}"
                : "Loading...",
          ),
          consumeTapEvents: true,
        ),
      );
    }

    // Add Clock Out marker with red color
    if (_outLoc != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("clock_out"),
          position: _outLoc!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: "Clock Out Location",
            snippet: outAt != null
                ? "Time: ${_fmtJM(outAt)}\n${outPlace ?? outAddress ?? 'Loading address...'}"
                : "Loading...",
          ),
          consumeTapEvents: true,
        ),
      );
    }

    // Add Live Location marker with blue color
    if (_liveLoc != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("live_location"),
          position: _liveLoc!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: "Live Location",
            snippet: livePlace ?? 'Current location',
          ),
          consumeTapEvents: true,
        ),
      );
    }

    // Use the most recent location as center, prioritizing live location
    final center =
        _liveLoc ?? _outLoc ?? _inLoc ?? const LatLng(18.0179, -76.8099);

    // Calculate initial zoom based on available locations
    double initialZoom = 12.0;
    if (_inLoc != null && (_outLoc != null || _liveLoc != null)) {
      // If we have multiple locations, use a wider zoom to fit both
      initialZoom = 11.0;
    } else if (_inLoc != null || _outLoc != null || _liveLoc != null) {
      // If we have one location, use a medium zoom
      initialZoom = 12.5;
    }

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
            Text(
              "Day: ${widget.dayId}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("Status: $status"),
            if (inAt != null)
              Text(
                "Clock In: ${_fmtJM(inAt)}${inPlace != null ? ' • $inPlace' : ''}",
              ),
            if (outAt != null)
              Text(
                "Clock Out: ${_fmtJM(outAt)}${outPlace != null ? ' • $outPlace' : ''}",
              ),
            if (_liveLoc != null)
              Text("Live: ${livePlace ?? 'Current location'}"),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.hardEdge,
                child: GoogleMap(
                  key: ValueKey("map_${widget.dayId}_${markers.length}"),
                  initialCameraPosition: CameraPosition(
                    target: center,
                    zoom: initialZoom,
                  ),
                  onMapCreated: (GoogleMapController controller) async {
                    try {
                      // Add a longer delay to ensure map is fully initialized
                      await Future.delayed(const Duration(milliseconds: 1000));

                      // Check if widget is still mounted before camera operations
                      if (!mounted) return;

                      // Try to animate camera with multiple fallback strategies
                      if (_inLoc != null && _outLoc != null) {
                        // Strategy 1: Try bounds fitting
                        try {
                          final bounds = LatLngBounds(
                            southwest: LatLng(
                              _inLoc!.latitude < _outLoc!.latitude
                                  ? _inLoc!.latitude
                                  : _outLoc!.latitude,
                              _inLoc!.longitude < _outLoc!.longitude
                                  ? _inLoc!.longitude
                                  : _outLoc!.longitude,
                            ),
                            northeast: LatLng(
                              _inLoc!.latitude > _outLoc!.latitude
                                  ? _inLoc!.latitude
                                  : _outLoc!.latitude,
                              _inLoc!.longitude > _outLoc!.longitude
                                  ? _inLoc!.longitude
                                  : _outLoc!.longitude,
                            ),
                          );
                          await controller.animateCamera(
                            CameraUpdate.newLatLngBounds(bounds, 100),
                          );
                        } catch (boundsError) {
                          // Fallback: Just zoom to the most recent location
                          debugPrint(
                            'Bounds camera animation failed: $boundsError',
                          );
                          await controller.animateCamera(
                            CameraUpdate.newLatLngZoom(_outLoc!, 12),
                          );
                        }
                      } else if (_inLoc != null) {
                        // If only clock-in location, zoom to it
                        await controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_inLoc!, 12.5),
                        );
                      } else if (_outLoc != null) {
                        // If only clock-out location, zoom to it
                        await controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_outLoc!, 12.5),
                        );
                      }
                    } catch (e) {
                      // Silently handle camera animation errors
                      debugPrint('Map camera animation error: $e');
                    }
                  },
                  markers: Set<Marker>.from(markers),
                  mapType: MapType.normal,
                  myLocationEnabled:
                      false, // Disable to avoid permission issues
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  buildingsEnabled: true,
                  trafficEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
