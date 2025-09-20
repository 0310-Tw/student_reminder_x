import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/user_service.dart';
import 'package:students_reminder/src/services/admin_service.dart';
import 'package:students_reminder/src/services/notification_service.dart';
import 'package:students_reminder/src/shared/list.dart';
import 'package:students_reminder/src/widgets/group_filter.dart';
import 'package:students_reminder/src/widgets/user_banner_notifications.dart';
import 'package:students_reminder/src/widgets/suspension_check.dart';
import 'package:students_reminder/src/shared/misc.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  String _group = 'mobile'; //default

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('User Management'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'ADMIN',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: SuspensionCheck(
        child: Column(
          children: [
            UserBannerNotifications(),
            GroupFilter(
              value: _group,
              onChanged: (val) => setState(() => _group = val),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: UserService.instance.watchUserByCourseGroup(_group),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError) {
                    return Center(child: Text('Error Detected: ${snap.error}'));
                  }

                  final docs = snap.data?.docs ?? [];

                  return ListView.separated(
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data();
                      final isMe = doc.id == uid;
                      final name =
                          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                      final course = (data['courseGroup'] ?? '').toString();
                      final isSuspended = data['status'] == 'suspended';
                      final isFlagged = data['flagged'] == true;
                      final email = data['email'] ?? '';

                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: isFlagged ? Colors.orange.shade50 : Colors.white,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: getInitialColor(name),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          if (isFlagged)
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'FLAGGED',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        course == 'mobile'
                                            ? 'Mobile App Development'
                                            : 'Web App Development',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        email,
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isMe) ...[
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'flag':
                                          isFlagged
                                              ? _showUnflagDialog(doc.id, name)
                                              : _showFlagDialog(doc.id, name);
                                          break;
                                        case 'suspend':
                                          isSuspended
                                              ? _showUnsuspendDialog(doc.id, name)
                                              : _showSuspendDialog(doc.id, name);
                                          break;
                                        case 'profile':
                                          Navigator.pushNamed(context, '/student/${doc.id}');
                                          break;
                                        case 'notifications':
                                          _showNotificationHistory(doc.id, name);
                                          break;
                                        case 'delete':
                                          _showDeleteDialog(doc.id, name);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'flag',
                                        child: Row(
                                          children: [
                                            Icon(
                                              isFlagged ? Icons.flag_outlined : Icons.flag,
                                              color: Colors.orange,
                                              size: 20,
                                            ),
                                            SizedBox(width: 12),
                                            Text(isFlagged ? 'Unflag User' : 'Flag User'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'suspend',
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSuspended ? Icons.check_circle : Icons.block,
                                              color: isSuspended ? Colors.green : Colors.red,
                                              size: 20,
                                            ),
                                            SizedBox(width: 12),
                                            Text(isSuspended ? 'Unsuspend User' : 'Suspend User'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'profile',
                                        child: Row(
                                          children: [
                                            Icon(Icons.person, color: Colors.blue, size: 20),
                                            SizedBox(width: 12),
                                            Text('View Profile'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'notifications',
                                        child: Row(
                                          children: [
                                            Icon(Icons.history, color: Colors.purple, size: 20),
                                            SizedBox(width: 12),
                                            Text('Notification History'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red, size: 20),
                                            SizedBox(width: 12),
                                            Text('Delete User'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    child: Icon(Icons.more_vert, color: Colors.grey.shade600),
                                  ),
                                ],
                              ],
                            ),
                            if (isFlagged || isSuspended) ...[
                              SizedBox(height: 8),
                              Center(
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSuspended ? Colors.red.shade100 : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSuspended ? Colors.red.shade300 : Colors.orange.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSuspended ? Icons.block : Icons.flag,
                                        size: 14,
                                        color: isSuspended ? Colors.red.shade700 : Colors.orange.shade700,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        isSuspended ? 'SUSPENDED' : 'FLAGGED',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSuspended ? Colors.red.shade700 : Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
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

  // All dialog methods below are **exactly as you wrote them**, unchanged
  void _showDeleteDialog(String userId, String userName) { /* ... */ }
  void _showFlagDialog(String userId, String userName) { /* ... */ }
  void _showUnflagDialog(String userId, String userName) { /* ... */ }
  void _showSuspendDialog(String userId, String userName) { /* ... */ }
  void _showUnsuspendDialog(String userId, String userName) { /* ... */ }
  Future<void> _sendUserNotification(String userId, String title, String body) async { /* ... */ }
  void _showNotificationHistory(String userId, String userName) { /* ... */ }
}
