import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/features/notes/dialogs/note_editor_dialog.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/note_service.dart';
import 'package:students_reminder/src/services/notification_service.dart';
import 'package:students_reminder/src/widgets/user_banner_notifications.dart';
import 'package:students_reminder/src/widgets/suspension_check.dart';

class MyNotesPage extends StatefulWidget {
  const MyNotesPage({super.key});

  @override
  State<MyNotesPage> createState() => _MyNotesPageState();
}

class _MyNotesPageState extends State<MyNotesPage> {
  String _searchQuery = '';
  String _visibilityFilter = 'all';
  DateTimeRange? _dueDateRange;
  final List<String> _selectedTags = [];
  String _sortBy = 'aud_dt';
  bool _sortAscending = false;
  final TextEditingController _searchController = TextEditingController();

  // Get all unique tags from notes
  Set<String> _getAllTags(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    Set<String> allTags = {};
    for (var doc in docs) {
      final data = doc.data();
      final tags = data['tags'] as List<dynamic>? ?? [];
      allTags.addAll(tags.cast<String>());
    }
    return allTags;
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your notes')),
      );
    }
    final uid = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('My Notes'),
        actions: [
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: _showSortDialog,
            icon: const Icon(Icons.arrow_downward_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "my_notes_fab",
        backgroundColor: const Color(0xFF3498DB),
        foregroundColor: Colors.white,
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => NoteEditorDialog(uid: uid),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: SuspensionCheck(
        restrictWriteAccess: true,
        child: Column(
          children: [
            const UserBannerNotifications(),
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search notes by title or body...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                  if (_selectedTags.isNotEmpty ||
                      _visibilityFilter != 'all' ||
                      _dueDateRange != null) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Active Filters:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: Color(0xFF5D6D7E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (_visibilityFilter != 'all')
                          Chip(
                            label: Text(
                              'Visibility: $_visibilityFilter',
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: Colors.orange[100],
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () =>
                                setState(() => _visibilityFilter = 'all'),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (_dueDateRange != null)
                          Chip(
                            label: Text(
                              'Due: ${_dueDateRange!.start.toString().split(' ').first} - ${_dueDateRange!.end.toString().split(' ').first}',
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: Colors.green[100],
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () =>
                                setState(() => _dueDateRange = null),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ..._selectedTags.map(
                          (tag) => Chip(
                            label: Text(
                              'Tag: $tag',
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: const Color(
                              0xFF3498DB,
                            ).withOpacity(0.1),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () =>
                                setState(() => _selectedTags.remove(tag)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: NotesService.instance.watchMyNotes(uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data?.docs ?? [];

                  final filteredDocs = docs.where((doc) {
                    final data = doc.data();
                    final title = (data['title'] ?? '')
                        .toString()
                        .toLowerCase();
                    final body = (data['body'] ?? '').toString().toLowerCase();
                    final visibility = data['visibility'] ?? 'private';
                    final dueDate = data['dueDate']?.toDate();

                    if (_searchQuery.isNotEmpty &&
                        !title.contains(_searchQuery) &&
                        !body.contains(_searchQuery)) {
                      return false;
                    }

                    if (_visibilityFilter != 'all' &&
                        visibility != _visibilityFilter) {
                      return false;
                    }

                    if (_dueDateRange != null && dueDate != null) {
                      if (dueDate.isBefore(_dueDateRange!.start) ||
                          dueDate.isAfter(_dueDateRange!.end)) {
                        return false;
                      }
                    }

                    if (_selectedTags.isNotEmpty) {
                      final noteTags = List<String>.from(data['tags'] ?? []);
                      if (!_selectedTags.any((tag) => noteTags.contains(tag))) {
                        return false;
                      }
                    }

                    return true;
                  }).toList();

                  filteredDocs.sort((a, b) {
                    final dataA = a.data();
                    final dataB = b.data();

                    switch (_sortBy) {
                      case 'title':
                        final titleA = (dataA['title'] ?? '')
                            .toString()
                            .toLowerCase();
                        final titleB = (dataB['title'] ?? '')
                            .toString()
                            .toLowerCase();
                        final comparison = titleA.compareTo(titleB);
                        return _sortAscending ? comparison : -comparison;
                      case 'dueDate':
                        final dueA = dataA['dueDate']?.toDate();
                        final dueB = dataB['dueDate']?.toDate();
                        if (dueA == null && dueB == null) return 0;
                        if (dueA == null) return 1;
                        if (dueB == null) return -1;
                        final comparison = dueA.compareTo(dueB);
                        return _sortAscending ? comparison : -comparison;
                      case 'aud_dt':
                      default:
                        final audA = dataA['aud_dt']?.toDate();
                        final audB = dataB['aud_dt']?.toDate();
                        if (audA == null && audB == null) return 0;
                        if (audA == null) return 1;
                        if (audB == null) return -1;
                        final comparison = audA.compareTo(audB);
                        return _sortAscending ? comparison : -comparison;
                    }
                  });

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Text(
                        docs.isEmpty
                            ? 'No notes to show. Click the + button to add a note.'
                            : 'No notes match your search criteria.',
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredDocs.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 2),
                    itemBuilder: (context, index) {
                      final data = filteredDocs[index];
                      final visible = data['visibility'] ?? 'private';
                      final title = (data['title'] ?? '').toString();
                      final body = (data['body'] ?? '').toString();
                      final tags = List<String>.from(data['tags'] ?? []);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      visible,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () async {
                                      await NotesService.instance.deleteNote(
                                        uid,
                                        data.id,
                                      );
                                    },
                                    icon: const Icon(Icons.delete_outlined),
                                    iconSize: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF5D6D7E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'Tags: ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF7B8794),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (tags.isEmpty)
                                    const Text(
                                      '(none)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF95A5BC),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        children: tags
                                            .map(
                                              (tag) => Chip(
                                                label: Text(
                                                  tag,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                backgroundColor: const Color(
                                                  0xFFF8F9FA,
                                                ),
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () async {
                                  await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => NoteEditorDialog(
                                      uid: uid,
                                      noteId: data.id,
                                      existing: data.data(),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Color(0xFF3498DB),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Edit',
                                        style: TextStyle(
                                          color: Color(0xFF3498DB),
                                        ),
                                      ),
                                    ],
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
    );
  }

  // Filter dialog
  void _showFilterDialog() {
    /* ... unchanged ... */
  }

  // Sort dialog
  void _showSortDialog() {
    /* ... unchanged ... */
  }
}
