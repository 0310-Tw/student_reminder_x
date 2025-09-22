import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/features/notes/dialogs/note_editor_dialog.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/note_service.dart';
import 'package:students_reminder/src/services/admin_service.dart';
import 'package:students_reminder/src/shared/misc.dart';

class AdminPublicFeeds extends StatefulWidget {
  const AdminPublicFeeds({super.key});

  @override
  State<AdminPublicFeeds> createState() => _AdminPublicFeedsState();
}

class _AdminPublicFeedsState extends State<AdminPublicFeeds> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper method to filter documents based on search query
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _filterDocuments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_searchQuery.isEmpty) {
      return docs;
    }

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered = [];

    for (final doc in docs) {
      final data = doc.data();
      final title = (data['title'] ?? '').toString().toLowerCase();
      final noteOwnerId = doc.reference.parent.parent?.id ?? '';

      // Check if title matches
      bool titleMatches = title.contains(_searchQuery);

      // Check if username matches (need to fetch user data)
      bool usernameMatches = false;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(noteOwnerId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          final firstName = (userData['firstName'] ?? '')
              .toString()
              .toLowerCase();
          final lastName = (userData['lastName'] ?? '')
              .toString()
              .toLowerCase();
          final fullName = '$firstName $lastName'.trim();

          usernameMatches =
              firstName.contains(_searchQuery) ||
              lastName.contains(_searchQuery) ||
              fullName.contains(_searchQuery);
        }
      } catch (e) {
        // If user fetch fails, continue with title matching only
      }

      if (titleMatches || usernameMatches) {
        filtered.add(doc);
      }
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view public feeds')),
      );
    }
    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Feeds'),
        backgroundColor: Color(0xFF1A237E), // Deep indigo
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by username or title...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: NotesService.instance.publicFeeds(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  print('Public feeds error: ${snap.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Error loading public notes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${snap.error}',
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: Text('Loading...'));
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No notes to show.'));
                }

                return FutureBuilder<
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>
                >(
                  future: _filterDocuments(docs),
                  builder: (context, filterSnapshot) {
                    if (filterSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final filteredDocs = filterSnapshot.data ?? docs;

                    if (filteredDocs.isEmpty && _searchQuery.isNotEmpty) {
                      return const Center(
                        child: Text('No notes match your search.'),
                      );
                    }

                    return ListView.separated(
                      itemCount: filteredDocs.length,
                      separatorBuilder: (_, __) => const Divider(height: 2),
                      itemBuilder: (context, i) {
                        final doc = filteredDocs[i];
                        final data = doc.data();
                        final ref = doc.reference;
                        final noteId = ref.id;
                        final noteOwnerId = ref.parent.parent?.id ?? '';

                        final visible =
                            (data['visibility'] ?? 'private') as String;
                        final title = (data['title'] ?? '').toString();
                        final body = (data['body'] ?? '').toString();
                        final isFlagged = data['flagged'] == true;

                        final likes = (data['likesCount'] ?? 0) as int;
                        final likedBy = Map<String, dynamic>.from(
                          data['likedBy'] ?? const {},
                        );
                        final bool isLiked = likedBy[uid] == true;

                        return Card(
                          margin: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          color: isFlagged ? Colors.red.shade50 : null,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Fetch and display user's actual name
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 4),
                                    FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(noteOwnerId)
                                          .get(),
                                      builder: (context, userSnapshot) {
                                        if (userSnapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return Text(
                                            'Loading user...',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          );
                                        }

                                        if (!userSnapshot.hasData ||
                                            !userSnapshot.data!.exists) {
                                          return Text(
                                            'Unknown User',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          );
                                        }

                                        final userData =
                                            userSnapshot.data!.data()
                                                as Map<String, dynamic>? ??
                                            {};
                                        final firstName =
                                            userData['firstName'] ?? '';
                                        final lastName =
                                            userData['lastName'] ?? '';
                                        final fullName = '$firstName $lastName'
                                            .trim();

                                        return Text(
                                          'User: ${fullName.isNotEmpty ? fullName : 'Unknown User'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),

                                // Header with visibility and admin info
                                Row(
                                  children: [
                                    Chip(
                                      label: Text(visible),
                                      backgroundColor: isFlagged
                                          ? Colors.red.shade200
                                          : null,
                                    ),
                                    if (isFlagged) ...[
                                      SizedBox(width: 8),
                                      Chip(
                                        label: Text(
                                          'FLAGGED',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                        backgroundColor: Colors.red,
                                        labelStyle: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                    SizedBox(width: 8),

                                    // Reports count indicator
                                    StreamBuilder<QuerySnapshot>(
                                      stream: ref
                                          .collection('reports')
                                          .snapshots(),
                                      builder: (context, reportsSnapshot) {
                                        if (!reportsSnapshot.hasData) {
                                          return SizedBox.shrink();
                                        }
                                        final reportsCount =
                                            reportsSnapshot.data!.docs.length;
                                        if (reportsCount == 0) {
                                          return SizedBox.shrink();
                                        }

                                        return Chip(
                                          label: Text(
                                            '$reportsCount Report${reportsCount > 1 ? 's' : ''}',
                                            style: TextStyle(fontSize: 10),
                                          ),
                                          backgroundColor:
                                              Colors.orange.shade200,
                                          labelStyle: TextStyle(
                                            color: Colors.orange.shade900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                    ),
                                    Spacer(),
                                  ],
                                ),

                                SizedBox(height: 8),

                                // Note content
                                if (title.isNotEmpty) ...[
                                  Text(
                                    title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                ],

                                Text(
                                  body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                SizedBox(height: 8),

                                // User info section
                                Row(
                                  children: [
                                    // Spacer(),
                                    // Admin actions for user
                                    if (noteOwnerId != uid) ...[
                                      TextButton(
                                        onPressed: () => _showUserAdminActions(
                                          context,
                                          noteOwnerId,
                                        ),
                                        child: Text(
                                          'Manage User',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                SizedBox(height: 12),

                                // Actions row
                                Row(
                                  children: [
                                    // Like section
                                    IconButton(
                                      tooltip: isLiked ? 'Unlike' : 'Like',
                                      icon: Icon(
                                        isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isLiked ? Colors.red : null,
                                      ),
                                      onPressed: () {
                                        NotesService.instance.toggleLike(
                                          noteRef: ref,
                                          uid: uid,
                                        );
                                      },
                                    ),
                                    Text('$likes'),

                                    Spacer(),

                                    // Admin actions for note
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.admin_panel_settings,
                                        color: Colors.red.shade700,
                                      ),
                                      onSelected: (action) =>
                                          _handleNoteAdminAction(
                                            context,
                                            action,
                                            ref,
                                            noteId,
                                            noteOwnerId,
                                            title,
                                          ),
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'flag',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.flag,
                                                color: Colors.orange,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                isFlagged
                                                    ? 'Unflag Note'
                                                    : 'Flag Note',
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Delete Note'),
                                            ],
                                          ),
                                        ),

                                        PopupMenuItem(
                                          value: 'view_reports',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.visibility,
                                                color: Colors.purple,
                                              ),
                                              SizedBox(width: 8),
                                              Text('View Reports'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

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

  Future<void> _handleNoteAdminAction(
    BuildContext context,
    String action,
    DocumentReference ref,
    String noteId,
    String noteOwnerId,
    String title,
  ) async {
    try {
      switch (action) {
        case 'flag':
          // Check if note is already flagged
          final noteDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(noteOwnerId)
              .collection('notes')
              .doc(noteId)
              .get();

          final isFlagged = noteDoc.data()?['flagged'] == true;

          if (isFlagged) {
            // Unflag the note
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Unflag Note'),
                content: Text(
                  'Are you sure you want to remove the flag from this note?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Unflag'),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              await AdminService.instance.unflagNote(noteOwnerId, noteId);
              displaySnackBar(context, 'Note unflagged successfully');
            }
          } else {
            // Flag the note
            final reason = await _askActionReason(
              context,
              'Flag Note',
              'Why are you flagging this note?',
            );
            if (reason != null && reason.trim().isNotEmpty) {
              await AdminService.instance.flagNote(
                noteOwnerId,
                noteId,
                reason.trim(),
              );
              displaySnackBar(context, 'Note flagged successfully');
            }
          }
          break;

        case 'delete':
          final confirmed = await _confirmDeletion(context, title);
          if (confirmed == true) {
            final reason = await _askActionReason(
              context,
              'Delete Note',
              'Reason for deletion:',
            );
            if (reason != null && reason.trim().isNotEmpty) {
              await AdminService.instance.deleteNote(
                noteOwnerId,
                noteId,
                reason.trim(),
              );
              displaySnackBar(context, 'Note deleted successfully');
            }
          }
          break;

        case 'report':
          final currentUser = AuthService.instance.currentUser;
          if (currentUser != null) {
            final reason = await askReportReason(context);
            if (reason != null && reason.trim().isNotEmpty) {
              await NotesService.instance.reportNote(
                noteRef: ref as DocumentReference<Map<String, dynamic>>,
                uid: currentUser.uid,
                reason: reason.trim(),
              );
              displaySnackBar(context, 'Report submitted as admin');
            }
          } else {
            displaySnackBar(context, 'Authentication required');
          }
          break;

        case 'view_reports':
          await _showReportsDialog(context, ref, title);
          break;
      }
    } catch (e) {
      displaySnackBar(context, 'Error: $e');
    }
  }

  Future<void> _showUserAdminActions(
    BuildContext context,
    String userId,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Management'),
        content: Text(
          'Choose an action for user: ${userId.substring(0, 8)}...',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final reason = await _askActionReason(
                context,
                'Flag User',
                'Why are you flagging this user?',
              );
              if (reason != null && reason.trim().isNotEmpty) {
                await AdminService.instance.flagUser(userId, reason.trim());
                displaySnackBar(context, 'User flagged successfully');
              }
            },
            child: Text('Flag User', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final confirmed = await _confirmAction(
                context,
                'Suspend User',
                'Are you sure you want to suspend this user?',
              );
              if (confirmed == true) {
                final reason = await _askActionReason(
                  context,
                  'Suspend User',
                  'Reason for suspension:',
                );
                if (reason != null && reason.trim().isNotEmpty) {
                  await AdminService.instance.suspendUser(
                    userId,
                    reason: reason.trim(),
                  );
                  displaySnackBar(context, 'User suspended successfully');
                }
              }
            },
            child: Text('Suspend User', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<String?> _askActionReason(
    BuildContext context,
    String title,
    String hint,
  ) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDeletion(BuildContext context, String title) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Note'),
        content: Text(
          'Are you sure you want to DELETE this note?\n\nTitle: "$title"\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmAction(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // Show all reports for a specific note
  Future<void> _showReportsDialog(
    BuildContext context,
    DocumentReference noteRef,
    String noteTitle,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reports for Note',
          style: TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Note title
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Note Title:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      noteTitle.isEmpty ? 'Untitled Note' : noteTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Reports list
              Text(
                'User Reports:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A237E),
                ),
              ),
              SizedBox(height: 8),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: noteRef
                      .collection('reports')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.report_off,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No reports found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final reports = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        final data = report.data() as Map<String, dynamic>;
                        final reporterId = report.id;
                        final reason = data['reason'] ?? 'No reason provided';
                        final createdAt = data['createdAt'] as Timestamp?;

                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Reporter info and timestamp
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 4),
                                    // Fetch and display reporter's actual name and ID
                                    Expanded(
                                      child: FutureBuilder<DocumentSnapshot>(
                                        future: FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(reporterId)
                                            .get(),
                                        builder: (context, userSnapshot) {
                                          if (userSnapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return Text(
                                              'Loading reporter...',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            );
                                          }

                                          if (!userSnapshot.hasData ||
                                              !userSnapshot.data!.exists) {
                                            return Text(
                                              'Reporter: Unknown User',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            );
                                          }

                                          final userData =
                                              userSnapshot.data!.data()
                                                  as Map<String, dynamic>? ??
                                              {};
                                          final firstName =
                                              userData['firstName'] ?? '';
                                          final lastName =
                                              userData['lastName'] ?? '';
                                          final fullName =
                                              '$firstName $lastName'.trim();

                                          return Text(
                                            'Reporter: ${fullName.isNotEmpty ? fullName : 'Unknown User'}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    if (createdAt != null)
                                      Text(
                                        _formatTimestamp(createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    SizedBox(width: 8),
                                    // Delete button
                                    IconButton(
                                      onPressed: () async {
                                        // Show confirmation dialog
                                        final bool?
                                        confirmDelete = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('Delete Report'),
                                            content: Text(
                                              'Are you sure you want to delete this report? This action cannot be undone.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                                child: Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                ),
                                                child: Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmDelete == true) {
                                          try {
                                            // Delete the report document
                                            await noteRef
                                                .collection('reports')
                                                .doc(reporterId)
                                                .delete();

                                            // Show success message
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Report deleted successfully',
                                                ),
                                                backgroundColor: Color(
                                                  0xFF27AE60,
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            // Show error message
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error deleting report: $e',
                                                ),
                                                backgroundColor: Color(
                                                  0xFFE74C3C,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.red[600],
                                      ),
                                      tooltip: 'Delete Report',
                                      constraints: BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      padding: EdgeInsets.all(4),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),

                                // Report reason
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: Color(0xFF1A237E))),
          ),
        ],
      ),
    );
  }

  // Helper method to format timestamps
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Simple report reason dialog for admin use
Future<String?> askReportReason(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Report note'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Briefly say what\'s wrong (spam, offensive, etc.)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Submit'),
        ),
      ],
    ),
  );
}
