import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/services/auth_service.dart';

class UserBannerNotifications extends StatelessWidget {
  const UserBannerNotifications({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) return SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        print('UserNotifications StreamBuilder triggered');
        print('Has data: ${snapshot.hasData}');
        print('Docs count: ${snapshot.data?.docs.length ?? 0}');

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('No notifications found or no data');
          return SizedBox.shrink();
        }

        final notifications = snapshot.data!.docs;
        print('Total notifications: ${notifications.length}');

        // Debug: Print all notifications
        for (int i = 0; i < notifications.length; i++) {
          final data = notifications[i].data() as Map;
          print(
            'Notification $i: ${data['type']} - ${data['severity']} - ${data['title']}',
          );
        }

        final criticalNotifications = notifications
            .where((doc) => (doc.data() as Map)['severity'] == 'critical')
            .toList();

        print('Critical notifications: ${criticalNotifications.length}');

        // Show critical notifications (suspensions) as prominent banners
        if (criticalNotifications.isNotEmpty) {
          final notification = criticalNotifications.first.data() as Map;
          return _buildCriticalNotificationBanner(
            context,
            notification,
            criticalNotifications.first.id,
          );
        }

        // Show warning notifications (flags) as smaller banners
        final warningNotifications = notifications
            .where((doc) => (doc.data() as Map)['severity'] == 'warning')
            .toList();

        if (warningNotifications.isNotEmpty) {
          final notification = warningNotifications.first.data() as Map;
          return _buildWarningNotificationBanner(
            context,
            notification,
            warningNotifications.first.id,
          );
        }

        // Show info notifications (unflag, etc.) as informational banners
        final infoNotifications = notifications
            .where((doc) => (doc.data() as Map)['severity'] == 'info')
            .toList();

        if (infoNotifications.isNotEmpty) {
          final notification = infoNotifications.first.data() as Map;
          return _buildInfoNotificationBanner(
            context,
            notification,
            infoNotifications.first.id,
          );
        }

        return SizedBox.shrink();
      },
    );
  }

  Widget _buildCriticalNotificationBanner(
    BuildContext context,
    Map notification,
    String notificationId,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_amber,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    notification['title'] ?? 'Important Notice',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _markAsRead(notificationId),
                  icon: Icon(Icons.close, color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              notification['message'] ?? '',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _markAsRead(notificationId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Acknowledge'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningNotificationBanner(
    BuildContext context,
    Map notification,
    String notificationId,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFF57700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.flag, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] ?? 'Account Notice',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (notification['message'] != null)
                    Text(
                      notification['message'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _markAsRead(notificationId),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoNotificationBanner(
    BuildContext context,
    Map notification,
    String notificationId,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] ?? 'Information',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (notification['message'] != null)
                    Text(
                      notification['message'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _markAsRead(notificationId),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
}
