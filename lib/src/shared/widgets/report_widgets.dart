import 'package:flutter/material.dart';
import 'package:students_reminder/src/services/report_service.dart';
import 'package:students_reminder/src/shared/misc.dart';

class ReportNoteDialog extends StatefulWidget {
  final String noteId;
  final String noteOwnerId;
  final String noteTitle;

  const ReportNoteDialog({
    super.key,
    required this.noteId,
    required this.noteOwnerId,
    required this.noteTitle,
  });

  @override
  State<ReportNoteDialog> createState() => _ReportNoteDialogState();
}

class _ReportNoteDialogState extends State<ReportNoteDialog> {
  String? selectedReason;
  final descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Report Note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reporting: "${widget.noteTitle}"'),
          SizedBox(height: 16),
          Text('Reason for reporting:'),
          SizedBox(height: 8),
          ...ReportService.instance.getNoteReportReasons().map(
            (reason) => RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: selectedReason,
              onChanged: (value) {
                setState(() {
                  selectedReason = value;
                });
              },
              dense: true,
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: descriptionController,
            decoration: InputDecoration(
              labelText: 'Additional details (optional)',
              hintText:
                  'Provide more context about why you\'re reporting this...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            maxLength: 500,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: selectedReason != null ? () => _submitReport() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          child: Text('Submit Report'),
        ),
      ],
    );
  }

  Future<void> _submitReport() async {
    try {
      await ReportService.instance.reportNote(
        noteId: widget.noteId,
        noteOwnerId: widget.noteOwnerId,
        reason: selectedReason!,
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        displaySnackBar(
          context,
          'Report submitted successfully. Thank you for helping keep our community safe.',
        );
      }
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, 'Error submitting report: $e');
      }
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }
}

class ReportUserDialog extends StatefulWidget {
  final String userId;
  final String userName;

  const ReportUserDialog({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  String? selectedReason;
  final descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Report User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reporting user: "${widget.userName}"'),
          SizedBox(height: 16),
          Text('Reason for reporting:'),
          SizedBox(height: 8),
          ...ReportService.instance.getUserReportReasons().map(
            (reason) => RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: selectedReason,
              onChanged: (value) {
                setState(() {
                  selectedReason = value;
                });
              },
              dense: true,
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: descriptionController,
            decoration: InputDecoration(
              labelText: 'Additional details (optional)',
              hintText: 'Provide more context about the user\'s behavior...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            maxLength: 500,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: selectedReason != null ? () => _submitReport() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          child: Text('Submit Report'),
        ),
      ],
    );
  }

  Future<void> _submitReport() async {
    try {
      await ReportService.instance.reportUser(
        userId: widget.userId,
        reason: selectedReason!,
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        displaySnackBar(
          context,
          'User report submitted successfully. Thank you for helping keep our community safe.',
        );
      }
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, 'Error submitting report: $e');
      }
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }
}

class ReportNoteButton extends StatelessWidget {
  final String noteId;
  final String noteOwnerId;
  final String noteTitle;

  const ReportNoteButton({
    super.key,
    required this.noteId,
    required this.noteOwnerId,
    required this.noteTitle,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.flag_outlined),
      onPressed: () => _showReportDialog(context),
      tooltip: 'Report this note',
    );
  }

  void _showReportDialog(BuildContext context) {
    String? selectedReason;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Report Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reporting: "$noteTitle"'),
              SizedBox(height: 16),
              Text('Reason for reporting:'),
              SizedBox(height: 8),
              ...ReportService.instance.getNoteReportReasons().map(
                (reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                    });
                  },
                  dense: true,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Additional details (optional)',
                  hintText:
                      'Provide more context about why you\'re reporting this...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 500,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedReason != null
                  ? () => _submitReport(
                      context,
                      selectedReason!,
                      descriptionController.text,
                    )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(
    BuildContext context,
    String reason,
    String description,
  ) async {
    try {
      await ReportService.instance.reportNote(
        noteId: noteId,
        noteOwnerId: noteOwnerId,
        reason: reason,
        description: description.trim().isEmpty ? null : description.trim(),
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        displaySnackBar(
          context,
          'Report submitted successfully. Thank you for helping keep our community safe.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        displaySnackBar(context, 'Error submitting report: $e');
      }
    }
  }
}

class ReportUserButton extends StatelessWidget {
  final String userId;
  final String userName;

  const ReportUserButton({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: Icon(Icons.flag_outlined, color: Colors.red),
      label: Text('Report User', style: TextStyle(color: Colors.red)),
      onPressed: () => _showReportDialog(context),
    );
  }

  void _showReportDialog(BuildContext context) {
    String? selectedReason;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Report User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reporting user: "$userName"'),
              SizedBox(height: 16),
              Text('Reason for reporting:'),
              SizedBox(height: 8),
              ...ReportService.instance.getUserReportReasons().map(
                (reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                    });
                  },
                  dense: true,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Additional details (optional)',
                  hintText:
                      'Provide more context about the user\'s behavior...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 500,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedReason != null
                  ? () => _submitReport(
                      context,
                      selectedReason!,
                      descriptionController.text,
                    )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(
    BuildContext context,
    String reason,
    String description,
  ) async {
    try {
      await ReportService.instance.reportUser(
        userId: userId,
        reason: reason,
        description: description.trim().isEmpty ? null : description.trim(),
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        displaySnackBar(
          context,
          'Report submitted successfully. Thank you for helping keep our community safe.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        displaySnackBar(context, 'Error submitting report: $e');
      }
    }
  }
}
