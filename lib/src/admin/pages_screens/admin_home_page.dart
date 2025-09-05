import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/services/admin_service.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/user_service.dart';
import 'package:students_reminder/src/services/notification_service.dart';
import 'package:students_reminder/src/shared/misc.dart';
import 'package:students_reminder/src/widgets/group_filter.dart';

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
        backgroundColor: Color(0xFF1A237E), // Deep indigo
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Color(0xFFE3F2FD), // Light blue background
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFF1976D2), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 16,
                  color: Color(0xFF1976D2),
                ),
                SizedBox(width: 4),
                Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Color(0xFF1976D2),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
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
                  separatorBuilder: (_, _) => Divider(height: 1),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final userId = doc.id;
                    final isMe = userId == uid;
                    final name =
                        '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                            .trim();
                    final course = (data['courseGroup'] ?? '').toString();
                    final email = data['email'] ?? '';
                    final isSuspended = data['status'] == 'suspended';
                    final isFlagged = data['flagged'] == true;

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSuspended
                              ? Color(0xFFD32F2F).withOpacity(0.3)
                              : isFlagged
                              ? Color(0xFFFF9800).withOpacity(0.3)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      color: isSuspended
                          ? Color(0xFFFFEBEE) // Light red
                          : isFlagged
                          ? Color(0xFFFFF3E0) // Light orange
                          : Colors.white,
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isSuspended
                              ? Color(0xFFD32F2F) // Professional red
                              : isFlagged
                              ? Color(0xFFFF9800) // Professional orange
                              : Color(0xFF1976D2), // Professional blue
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(name.isEmpty ? 'Unknown User' : name),
                            ),
                            if (isSuspended)
                              Chip(
                                label: Text(
                                  'SUSPENDED',
                                  style: TextStyle(fontSize: 10),
                                ),
                                backgroundColor: Colors.red,
                                labelStyle: TextStyle(color: Colors.white),
                              ),
                            if (isFlagged && !isSuspended)
                              Chip(
                                label: Text(
                                  'FLAGGED',
                                  style: TextStyle(fontSize: 10),
                                ),
                                backgroundColor: Colors.orange,
                                labelStyle: TextStyle(color: Colors.white),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course == 'mobile'
                                  ? 'Mobile App Development'
                                  : 'Web App Development',
                            ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                        trailing: isMe
                            ? Text(
                                'Your Profile',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              )
                            : PopupMenuButton<String>(
                                onSelected: (action) =>
                                    _handleAdminAction(action, userId, name),
                                itemBuilder: (context) => [
                                  if (!isSuspended) ...[
                                    PopupMenuItem(
                                      value: isFlagged ? 'unflag' : 'flag',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.flag,
                                            color: Color(
                                              0xFFFF9800,
                                            ), // Professional orange
                                            size: 20,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            isFlagged
                                                ? 'Unflag User'
                                                : 'Flag User',
                                            style: TextStyle(
                                              color: Color(0xFF2E3440),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'suspend',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.block,
                                            color: Color(
                                              0xFFD32F2F,
                                            ), // Professional red
                                            size: 20,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Suspend User',
                                            style: TextStyle(
                                              color: Color(0xFF2E3440),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (isSuspended)
                                    PopupMenuItem(
                                      value: 'unsuspend',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Color(
                                              0xFF4CAF50,
                                            ), // Professional green
                                            size: 20,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Unsuspend User',
                                            style: TextStyle(
                                              color: Color(0xFF2E3440),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  PopupMenuItem(
                                    value: 'view',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          color: Color(
                                            0xFF1976D2,
                                          ), // Professional blue
                                          size: 20,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'View Profile',
                                          style: TextStyle(
                                            color: Color(0xFF2E3440),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_forever,
                                          color: Color(
                                            0xFFD32F2F,
                                          ), // Professional red
                                          size: 20,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Delete User',
                                          style: TextStyle(
                                            color: Color(0xFFD32F2F),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                        onTap: () {
                          // Open the Student Profile
                          Navigator.pushNamed(context, '/student/$userId');
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
    );
  }

  Future<void> _handleAdminAction(
    String action,
    String userId,
    String userName,
  ) async {
    try {
      switch (action) {
        case 'flag':
          final reason = await _askActionReason(
            context,
            'Flag User',
            'Why are you flagging this user? (This will be sent to the user as a notification)',
          );
          if (reason != null && reason.trim().isNotEmpty) {
            await AdminService.instance.flagUser(userId, reason.trim());
            // Send notification to user about being flagged
            await _sendFlagNotificationToUser(userId, userName, reason.trim());
            displaySnackBar(context, 'User flagged and notified successfully');
          }
          break;

        case 'unflag':
          final confirmed = await _confirmAction(
            context,
            'Unflag User',
            'Are you sure you want to unflag $userName?',
          );
          if (confirmed == true) {
            await AdminService.instance.unflagUser(userId);
            // Send notification to user about being unflagged
            await _sendUnflagNotificationToUser(userId, userName);
            displaySnackBar(
              context,
              'User unflagged and notified successfully',
            );
          }
          break;

        case 'suspend':
          final confirmed = await _confirmSuspension(context, userName);
          if (confirmed == true) {
            final reason = await _askActionReason(
              context,
              'Suspend User',
              'Reason for suspension (this will restrict user access):',
            );
            if (reason != null && reason.trim().isNotEmpty) {
              await AdminService.instance.suspendUser(
                userId,
                reason: reason.trim(),
              );
              // Send notification to user about suspension
              await _sendSuspensionNotificationToUser(
                userId,
                userName,
                reason.trim(),
              );
              displaySnackBar(
                context,
                'User suspended and notified successfully',
              );
            }
          }
          break;

        case 'unsuspend':
          final confirmed = await _confirmAction(
            context,
            'Unsuspend User',
            'Are you sure you want to unsuspend $userName?',
          );
          if (confirmed == true) {
            await AdminService.instance.unsuspendUser(userId);
            displaySnackBar(context, 'User unsuspended successfully');
          }
          break;

        case 'delete':
          final confirmed = await _confirmUserDeletion(context, userName);
          if (confirmed == true) {
            final confirmationText = await _askDeletionConfirmation(
              context,
              userName,
            );
            if (confirmationText == 'DELETE') {
              await AdminService.instance.deleteUser(userId);
              displaySnackBar(context, 'User deleted successfully');
            } else {
              displaySnackBar(
                context,
                'User deletion cancelled - confirmation text did not match',
              );
            }
          }
          break;

        case 'view':
          Navigator.pushNamed(context, '/student/$userId');
          break;
      }
    } catch (e) {
      displaySnackBar(context, 'Error: $e');
    }
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

  Future<bool?> _confirmSuspension(
    BuildContext context,
    String userName,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Suspend User'),
        content: Text(
          'Are you sure you want to SUSPEND $userName?\n\nThis will prevent them from accessing the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Suspend', style: TextStyle(color: Colors.white)),
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

  Future<void> _sendFlagNotificationToUser(
    String userId,
    String userName,
    String reason,
  ) async {
    try {
      print('🔔 Attempting to send flag notification to user: $userId');
      print('📝 Reason: $reason');

      // Create a notification document for the user
      final notificationRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'type': 'flag',
            'title': 'Account Flagged',
            'message':
                'Your account has been flagged by an administrator.\n\nReason: $reason\n\nPlease review our community guidelines and adjust your behavior accordingly.',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'severity': 'warning',
          });

      print('✅ Flag notification created with ID: ${notificationRef.id}');

      // Also update the user's profile to show flag status
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'flaggedAt': FieldValue.serverTimestamp(),
        'flagReason': reason,
      });

      print('✅ User profile updated with flag status');

      // Send push notification to user's device
      try {
        // Get user's FCM token from their profile
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        final userData = userDoc.data();
        final fcmToken = userData?['fcmToken'] as String?;

        if (fcmToken != null && fcmToken.isNotEmpty) {
          print(
            '📱 Sending push notification to FCM token: ${fcmToken.substring(0, 20)}...',
          );

          final pushSent = await NotificationService.sendPushNotificationv2(
            deviceToken: fcmToken,
            title: 'Account Flagged',
            body: 'Your account has been flagged. Reason: $reason',
          );

          if (pushSent) {
            print('✅ Push notification sent successfully');
          } else {
            print('⚠️ Push notification failed to send');
          }
        } else {
          print('⚠️ No FCM token found for user, skipping push notification');
        }
      } catch (pushError) {
        print('❌ Error sending push notification: $pushError');
        // Don't throw error - in-app notification was still created successfully
      }
    } catch (e) {
      print('❌ Error sending flag notification: $e');
      // Re-throw to let the caller know there was an error
      rethrow;
    }
  }

  Future<void> _sendUnflagNotificationToUser(
    String userId,
    String userName,
  ) async {
    try {
      // Create a notification document for the user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'type': 'unflag',
            'title': 'Flag Removed',
            'message':
                'Good news! The flag on your account has been removed by an administrator.\n\nYou can now continue using the platform normally. Thank you for your cooperation.',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'severity': 'info',
          });
    } catch (e) {
      print('Error sending unflag notification: $e');
    }
  }

  Future<void> _sendSuspensionNotificationToUser(
    String userId,
    String userName,
    String reason,
  ) async {
    try {
      // Create a notification document for the user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'type': 'suspension',
            'title': 'Account Suspended',
            'message':
                'Your account has been suspended by an administrator.\n\nReason: $reason\n\nWhile suspended, you can only view content but cannot post, comment, or interact. Contact support if you believe this is an error.',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'severity': 'critical',
          });

      // Update user's profile with suspension details
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'suspendedAt': FieldValue.serverTimestamp(),
        'suspensionReason': reason,
      });
    } catch (e) {
      print('Error sending suspension notification: $e');
    }
  }

  Future<bool?> _confirmUserDeletion(
    BuildContext context,
    String userName,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Color(0xFFD32F2F), size: 28),
            SizedBox(width: 12),
            Text(
              'Delete User',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to PERMANENTLY DELETE $userName?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFD32F2F).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action will:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('• Delete all user data permanently'),
                  Text('• Remove all user posts and comments'),
                  Text('• Cannot be undone'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            child: Text('Continue to Delete'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askDeletionConfirmation(
    BuildContext context,
    String userName,
  ) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Confirm Deletion',
          style: TextStyle(
            color: Color(0xFFD32F2F),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To confirm deletion of $userName, type "DELETE" exactly as shown:',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Type DELETE here',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2),
                ),
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '⚠️ This action is irreversible!',
                style: TextStyle(
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            child: Text('DELETE USER'),
          ),
        ],
      ),
    );
  }
}
