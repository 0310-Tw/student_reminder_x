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

class AdminProfileviewPage extends StatefulWidget {
  const AdminProfileviewPage({super.key});

  @override
  State<AdminProfileviewPage> createState() => _AdminProfileviewPageState();
}

class _AdminProfileviewPageState extends State<AdminProfileviewPage> {
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

  void _showDeleteDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Are you sure you want to permanently delete $userName?',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'This action cannot be undone. All user data will be permanently removed.',
              style: TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await AdminService.instance.deleteUser(userId);
                // Note: No notification sent as user document is deleted

                if (mounted) {
                  Navigator.pop(context);
                  displaySnackBar(
                    context,
                    '$userName has been deleted',
                    backgroundColor: Colors.green,
                  );
                }
              } catch (e) {
                if (mounted) {
                  displaySnackBar(
                    context,
                    'Error deleting user: $e',
                    backgroundColor: Colors.red,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFlagDialog(String userId, String userName) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Flag User'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Flag $userName?'),
                SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason for flagging',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                if (mounted) {
                  displaySnackBar(
                    context,
                    'Please provide a reason',
                    backgroundColor: Colors.orange,
                  );
                }
                return;
              }

              try {
                // Show loading indicator
                displaySnackBar(
                  context,
                  'Flagging $userName and sending notification...',
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 2),
                );

                await AdminService.instance.flagUser(
                  userId,
                  reasonController.text.trim(),
                );
                await _sendUserNotification(
                  userId,
                  'Account Flagged',
                  'Your account has been flagged: ${reasonController.text.trim()}',
                );

                if (mounted) {
                  Navigator.pop(context);
                  displaySnackBar(
                    context,
                    '$userName has been flagged and notified',
                    backgroundColor: Colors.green,
                  );
                }
              } catch (e) {
                if (mounted) {
                  displaySnackBar(
                    context,
                    'Error flagging user: $e',
                    backgroundColor: Colors.red,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Flag User'),
          ),
        ],
      ),
    );
  }

  void _showUnflagDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unflag User'),
        content: Text('Remove flag from $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await AdminService.instance.unflagUser(userId);
                await _sendUserNotification(
                  userId,
                  'Account Flag Removed',
                  'The flag on your account has been removed.',
                );

                if (mounted) {
                  Navigator.pop(context);
                  displaySnackBar(
                    context,
                    '$userName has been unflagged',
                    backgroundColor: Colors.green,
                  );
                }
              } catch (e) {
                if (mounted) {
                  displaySnackBar(
                    context,
                    'Error unflagging user: $e',
                    backgroundColor: Colors.red,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Unflag'),
          ),
        ],
      ),
    );
  }

  void _showSuspendDialog(String userId, String userName) {
    final reasonController = TextEditingController();
    DateTime? suspendUntil;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Suspend User'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Suspend $userName?'),
                  SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: 'Reason for suspension',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Suspend until: '),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() => suspendUntil = date);
                          }
                        },
                        child: Text(
                          suspendUntil != null
                              ? '${suspendUntil!.day}/${suspendUntil!.month}/${suspendUntil!.year}'
                              : 'Select Date',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  if (mounted) {
                    displaySnackBar(
                      context,
                      'Please provide a reason',
                      backgroundColor: Colors.orange,
                    );
                  }
                  return;
                }

                try {
                  // Show loading indicator
                  displaySnackBar(
                    context,
                    'Suspending $userName and sending notification...',
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 3),
                  );

                  await AdminService.instance.suspendUser(
                    userId,
                    reason: reasonController.text.trim(),
                    until: suspendUntil,
                  );

                  final untilText = suspendUntil != null
                      ? ' until ${suspendUntil!.day}/${suspendUntil!.month}/${suspendUntil!.year}'
                      : '';

                  await _sendUserNotification(
                    userId,
                    'Account Suspended',
                    'Your account has been suspended$untilText: ${reasonController.text.trim()}',
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    displaySnackBar(
                      context,
                      '$userName has been suspended and notified',
                      backgroundColor: Colors.red.shade700,
                      duration: Duration(seconds: 4),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    displaySnackBar(
                      context,
                      'Error suspending user: $e',
                      backgroundColor: Colors.red,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Suspend'),
            ),
          ],
        ),
      ),
    );
  }
  //deffrf

  void _showUnsuspendDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unsuspend User'),
        content: Text('Remove suspension from $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await AdminService.instance.unsuspendUser(userId);
                await _sendUserNotification(
                  userId,
                  'Account Unsuspended',
                  'Your account suspension has been lifted.',
                );

                if (mounted) {
                  Navigator.pop(context);
                  displaySnackBar(
                    context,
                    '$userName has been unsuspended',
                    backgroundColor: Colors.green,
                  );
                }
              } catch (e) {
                if (mounted) {
                  displaySnackBar(
                    context,
                    'Error unsuspending user: $e',
                    backgroundColor: Colors.red,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Unsuspend'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendUserNotification(
    String userId,
    String title,
    String body,
  ) async {
    try {
      // Get user's FCM token and email from their user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final fcmToken = userData['fcmToken'];
        final userEmail = userData['email'];
        final userName =
            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                .trim();

        bool notificationSent = false;

        // Try to send push notification first
        if (fcmToken != null && fcmToken.toString().isNotEmpty) {
          try {
            final success = await NotificationService.sendPushNotification(
              deviceToken: fcmToken,
              title: title,
              body: body,
            );
            if (success) {
              notificationSent = true;
              print('Push notification sent successfully to $userName');
            }
          } catch (e) {
            print('Push notification failed for $userName: $e');
          }
        }

        // Always add to user's notifications subcollection for in-app notifications
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
              'title': title,
              'body': body,
              'message': body, // Add message field for banner notifications
              'type': 'admin_action',
              'priority': 'high',
              'severity': title.contains('Unsuspended')
                  ? 'info'
                  : (title.contains('Suspended') ? 'critical' : 'warning'),
              'read': false,
              'actionBy': AuthService.instance.currentUser?.email ?? 'Admin',
              'actionDate': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
            });

        // Log the admin action for audit trail
        await FirebaseFirestore.instance.collection('adminActions').add({
          'action': 'notification_sent',
          'targetUserId': userId,
          'targetUserEmail': userEmail,
          'targetUserName': userName,
          'adminId': AuthService.instance.currentUser?.uid,
          'adminEmail': AuthService.instance.currentUser?.email,
          'notificationTitle': title,
          'notificationBody': body,
          'pushNotificationSent': notificationSent,
          'timestamp': FieldValue.serverTimestamp(),
        });

        print('In-app notification stored for $userName');

        // If push notification failed and we have email, could implement email backup
        if (!notificationSent && userEmail != null) {
          print('Could send email notification to $userEmail as backup');
          // Email notification implementation could be added here
        }
      } else {
        print('User document not found for userId: $userId');
      }
    } catch (e) {
      print('Error sending notification to user $userId: $e');

      // Log the error for debugging
      try {
        await FirebaseFirestore.instance.collection('adminActions').add({
          'action': 'notification_error',
          'targetUserId': userId,
          'adminId': AuthService.instance.currentUser?.uid,
          'adminEmail': AuthService.instance.currentUser?.email,
          'error': e.toString(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (logError) {
        print('Failed to log error: $logError');
      }
    }
  }

  // Method to show notification history for debugging
  void _showNotificationHistory(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notification History - $userName'),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('notifications')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 48),
                            SizedBox(height: 8),
                            Text('Error loading notifications'),
                            Text(
                              '${snapshot.error}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_off,
                              color: Colors.grey,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text('No notifications found'),
                            Text(
                              'No admin notifications have been sent to this user yet.',
                            ),
                          ],
                        ),
                      );
                    }

                    // Manually sort notifications by timestamp (newest first)
                    final docs = snapshot.data!.docs.toList();
                    docs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime =
                          aData['createdAt'] as Timestamp? ??
                          aData['actionDate'] as Timestamp?;
                      final bTime =
                          bData['createdAt'] as Timestamp? ??
                          bData['actionDate'] as Timestamp?;

                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;

                      return bTime.compareTo(aTime); // Newest first
                    });

                    // Limit to most recent 20 notifications
                    final limitedDocs = docs.take(20).toList();

                    return ListView.builder(
                      itemCount: limitedDocs.length,
                      itemBuilder: (context, index) {
                        final doc = limitedDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final timestamp = data['createdAt'] as Timestamp?;
                        final actionTimestamp =
                            data['actionDate'] as Timestamp?;
                        final date =
                            timestamp?.toDate() ?? actionTimestamp?.toDate();
                        final notificationType = data['type'] ?? 'unknown';
                        final actionBy = data['actionBy'] ?? 'Admin';

                        // Determine icon and color based on notification type
                        IconData iconData = Icons.notifications;
                        Color iconColor = data['read'] == true
                            ? Colors.grey
                            : Color(0xFF3498DB);

                        switch (notificationType) {
                          case 'admin_action':
                            iconData = Icons.admin_panel_settings;
                            iconColor = data['read'] == true
                                ? Colors.grey
                                : Color(0xFFE74C3C);
                            break;
                          case 'attendance_update':
                            iconData = Icons.event_available;
                            iconColor = data['read'] == true
                                ? Colors.grey
                                : Color(0xFF27AE60);
                            break;
                          case 'flag':
                            iconData = Icons.flag;
                            iconColor = data['read'] == true
                                ? Colors.grey
                                : Color(0xFFF39C12);
                            break;
                          case 'suspension':
                            iconData = Icons.block;
                            iconColor = data['read'] == true
                                ? Colors.grey
                                : Color(0xFFE74C3C);
                            break;
                        }

                        return Card(
                          margin: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          child: ListTile(
                            leading: Icon(iconData, color: iconColor),
                            title: Text(
                              data['title'] ?? 'No Title',
                              style: TextStyle(
                                fontWeight: data['read'] == true
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['body'] ?? 'No Content'),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 12,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'By: $actionBy',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (date != null)
                                      Text(
                                        '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (data['read'] == true)
                                  Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF27AE60),
                                    size: 16,
                                  )
                                else
                                  Icon(
                                    Icons.fiber_new,
                                    color: Color(0xFFE74C3C),
                                    size: 16,
                                  ),
                                SizedBox(height: 4),
                                Text(
                                  notificationType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () async {
                              // Mark as read when tapped
                              if (data['read'] != true) {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(userId)
                                      .collection('notifications')
                                      .doc(doc.id)
                                      .update({'read': true});
                                } catch (e) {
                                  print(
                                    'Error marking notification as read: $e',
                                  );
                                }
                              }
                            },
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
          TextButton.icon(
            onPressed: () async {
              // Mark all notifications as read
              try {
                final batch = FirebaseFirestore.instance.batch();
                final notifications = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('notifications')
                    .where('read', isEqualTo: false)
                    .get();

                for (final doc in notifications.docs) {
                  batch.update(doc.reference, {'read': true});
                }

                await batch.commit();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Marked ${notifications.docs.length} notifications as read',
                    ),
                    backgroundColor: Color(0xFF27AE60),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error marking notifications as read: $e'),
                    backgroundColor: Color(0xFFE74C3C),
                  ),
                );
              }
            },
            icon: Icon(Icons.done_all),
            label: Text('Mark All Read'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
