import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/features/notes/dialogs/note_editor_dialog.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/note_service.dart';
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
          IconButton(
            onPressed: () => _showLogoutDialog(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
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

                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          SizedBox(height: 16),
                          Text('Error loading notes: ${snap.error}'),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    );
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
    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: NotesService.instance.watchMyNotes(
            AuthService.instance.currentUser!.uid,
          ),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            final allTags = _getAllTags(docs);

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Filter Notes'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Visibility Filter
                        const Text(
                          'Visibility:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _visibilityFilter,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All Notes'),
                            ),
                            DropdownMenuItem(
                              value: 'public',
                              child: Text('Public Only'),
                            ),
                            DropdownMenuItem(
                              value: 'private',
                              child: Text('Private Only'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              _visibilityFilter = value ?? 'all';
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Due Date Range Filter
                        const Text(
                          'Due Date Range:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final DateTimeRange? picked =
                                      await showDateRangePicker(
                                        context: context,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                        initialDateRange: _dueDateRange,
                                      );
                                  if (picked != null) {
                                    setDialogState(() {
                                      _dueDateRange = picked;
                                    });
                                  }
                                },
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                                label: Text(
                                  _dueDateRange == null
                                      ? 'Select Date Range'
                                      : '${_dueDateRange!.start.toString().split(' ').first} - ${_dueDateRange!.end.toString().split(' ').first}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            if (_dueDateRange != null)
                              IconButton(
                                onPressed: () {
                                  setDialogState(() {
                                    _dueDateRange = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 16),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Tags Filter
                        const Text(
                          'Tags:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (allTags.isEmpty)
                          const Text(
                            'No tags available',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: allTags.map((tag) {
                                  final isSelected = _selectedTags.contains(
                                    tag,
                                  );
                                  return FilterChip(
                                    label: Text(
                                      tag,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setDialogState(() {
                                        if (selected) {
                                          _selectedTags.add(tag);
                                        } else {
                                          _selectedTags.remove(tag);
                                        }
                                      });
                                    },
                                    backgroundColor: Colors.grey[100],
                                    selectedColor: const Color(
                                      0xFF3498DB,
                                    ).withOpacity(0.2),
                                    checkmarkColor: const Color(0xFF3498DB),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          _visibilityFilter = 'all';
                          _dueDateRange = null;
                          _selectedTags.clear();
                        });
                      },
                      child: const Text('Clear All'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          // Filters are already updated in real-time
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // Sort dialog
  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Sort Notes'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sort by:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    title: const Text('Date Created/Modified'),
                    subtitle: const Text('Most recent changes first'),
                    value: 'aud_dt',
                    groupValue: _sortBy,
                    onChanged: (value) {
                      setDialogState(() {
                        _sortBy = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Title'),
                    subtitle: const Text('Alphabetical order'),
                    value: 'title',
                    groupValue: _sortBy,
                    onChanged: (value) {
                      setDialogState(() {
                        _sortBy = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Due Date'),
                    subtitle: const Text('Earliest due dates first'),
                    value: 'dueDate',
                    groupValue: _sortBy,
                    onChanged: (value) {
                      setDialogState(() {
                        _sortBy = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Order:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(_sortAscending ? 'Ascending' : 'Descending'),
                    subtitle: Text(
                      _sortAscending
                          ? 'A to Z, oldest to newest'
                          : 'Z to A, newest to oldest',
                    ),
                    value: _sortAscending,
                    onChanged: (value) {
                      setDialogState(() {
                        _sortAscending = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // Sort options are already updated
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
          content: Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Logout'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Logging out...'),
              ],
            ),
          ),
        );

        // Perform logout
        await AuthService.instance.logout();

        // Navigation will be handled automatically by the auth stream
      }
    } catch (e) {
      // Pop loading dialog if it exists
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
