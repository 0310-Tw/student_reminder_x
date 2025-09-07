import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:students_reminder/src/features/notes/dialogs/note_editor_dialog.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/note_service.dart';

class PublicFeeds extends StatefulWidget {
  const PublicFeeds({super.key});

  @override
  State<PublicFeeds> createState() => _PublicFeedsState();
}

class _PublicFeedsState extends State<PublicFeeds> {
  final uid = AuthService.instance.currentUser!.uid;

  Future<void> _clockIn() async {
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
    if (now.isAfter(eightAM) && now.isBefore(eightThirty)) {
      status = "Early";
    } else if (now.isAfter(eightThirty) && now.isBefore(DateTime(now.year, now.month, now.day, 16))) {
      status = "Late";
      final reason = await _askLateReason();
      if (reason == null || reason.trim().isEmpty) {
        _showSnack("Late reason required.");
        return;
      }
      status += " — Reason: $reason";
    } else {
      _showSnack("Too late to clock in.");
      return;
    }

    // 🔥 Save to Firestore here if needed
    await FirebaseFirestore.instance.collection('attendance').add({
  'uid': uid,
  'clockInAt': Timestamp.now(),
  'location': GeoPoint(location.latitude, location.longitude),
  'status': status,
});


    _showSnack("Clocked in: $status at ${location.latitude}, ${location.longitude}");
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'Location services disabled';

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        throw 'Location permission denied';
      }
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<String?> _askLateReason() async {
    String reason = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Late Reason'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => reason = value,
          decoration: InputDecoration(hintText: 'Why are you late?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, reason), child: Text('Submit')),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> askReportReason(BuildContext context) async {
    String reason = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Report Note'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => reason = value,
          decoration: InputDecoration(hintText: 'Why are you reporting this note?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, reason), child: Text('Submit')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Public Feeds')),
      body: Column(
        children: [
          // 🕒 Clock In Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _clockIn,
              icon: Icon(Icons.access_time),
              label: Text("Clock In"),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
            ),
          ),

          // 📰 Public Feeds
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: NotesService.instance.publicFeeds(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData) {
                  return const Center(child: Text('Loading...'));
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No notes to show. Click the + button to add a note.'),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 2),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final ref = doc.reference;

                    final visible = (data['visibility'] ?? 'private') as String;
                    final title = (data['title'] ?? '').toString();
                    final body = (data['body'] ?? '').toString();

                    final likes = (data['likesCount'] ?? 0) as int;
                    final likedBy = Map<String, dynamic>.from(data['likedBy'] ?? const {});
                    final bool isLiked = likedBy[uid] == true;

                    return ListTile(
                      leading: Chip(label: Text(visible)),
                      title: Text(title),
                      subtitle: Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(likes.toString()),
                          IconButton(
                            tooltip: isLiked ? 'Unlike' : 'Like',
                            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                            onPressed: () {
                              NotesService.instance.toggleLike(noteRef: ref, uid: uid);
                            },
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'report') {
                                final reason = await askReportReason(context);
                                if (reason != null && reason.trim().isNotEmpty) {
                                  await NotesService.instance.reportNote(
                                    noteRef: ref,
                                    uid: uid,
                                    reason: reason.trim(),
                                  );
                                  _showSnack('Thanks — report submitted.');
                                }
                              } else if (v == 'unreport') {
                                await NotesService.instance.unreportNote(noteRef: ref, uid: uid);
                                _showSnack('Your report was removed.');
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return const [
                                PopupMenuItem(value: 'report', child: Text('Report')),
                                PopupMenuItem(value: 'unreport', child: Text('Undo report')),
                              ];
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        // Optional: navigate to detail page
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ➕ Add Note
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => NoteEditorDialog(uid: uid),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
