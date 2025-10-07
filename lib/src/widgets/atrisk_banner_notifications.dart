import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AtRiskBannerNotifications extends StatefulWidget {
  const AtRiskBannerNotifications({super.key});

  @override
  State<AtRiskBannerNotifications> createState() =>
      _AtRiskBannerNotificationsState();
}

class _AtRiskBannerNotificationsState extends State<AtRiskBannerNotifications> {
  // Track notification state to prevent duplicates - use static to persist across rebuilds
  static final Map<String, String> _lastNotificationsSent = {};

  /// Get stream of at-risk status from the existing at-risk collection
  /// This leverages the Firebase Cloud Functions that automatically monitor attendance
  Stream<DocumentSnapshot> _getAtRiskStatusStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('at-risk')
        .doc('current_status')
        .snapshots();
  }

  /// Send push notification for at-risk status with duplicate prevention
  Future<void> _sendAtRiskNotification({
    required String riskType,
    required String title,
    required String body,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    // Create unique key combining user ID, risk type, and date
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final notificationKey = '${user.uid}_${riskType}_$dateKey';

    // Check if we already sent this notification today (persistent check)
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSent = prefs.getString('last_notification_$notificationKey');
      if (lastSent == dateKey) {
        print('Notification already sent today for: $notificationKey');
        return;
      }
    } catch (e) {
      print('Error checking notification cache: $e');
    }

    // Check static cache as secondary check
    if (_lastNotificationsSent[notificationKey] == dateKey) {
      print('Notification already sent (cached) for: $notificationKey');
      return;
    }

    try {
      print('Sending at-risk notification: $riskType for user: ${user.uid}');

      final token = await NotificationService.getFCMToken();
      if (token != null) {
        final success = await NotificationService.sendPushNotification(
          deviceToken: token,
          title: title,
          body: body,
        );

        if (success) {
          // Mark as sent in both caches
          _lastNotificationsSent[notificationKey] = dateKey;

          // Persist to SharedPreferences
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'last_notification_$notificationKey',
              dateKey,
            );
          } catch (e) {
            print('Error saving notification cache: $e');
          }

          print('At-risk notification sent successfully: $riskType');
        } else {
          print('Failed to send at-risk notification: $riskType');
        }
      } else {
        print('No FCM token available for at-risk notification');
      }
    } catch (e) {
      print('Error sending at-risk notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) return SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: _getAtRiskStatusStream(user.uid),
      builder: (context, snapshot) {
        // Handle errors or loading states
        if (snapshot.hasError) {
          print('AtRiskBannerNotifications error: ${snapshot.error}');
          return SizedBox.shrink();
        }

        if (!snapshot.hasData ||
            snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.data!.exists) {
          return SizedBox.shrink();
        }

        final atRiskData = snapshot.data!.data() as Map<String, dynamic>?;
        if (atRiskData == null) return SizedBox.shrink();

        final isAtRisk = atRiskData['isAtRisk'] ?? false;
        if (!isAtRisk) return SizedBox.shrink();

        // Get risk factors to determine which banner to show
        final riskFactors = atRiskData['riskFactors'] as Map<String, dynamic>?;
        final weeklyRisk = riskFactors?['weeklyRisk'] ?? false;
        final monthlyRisk = riskFactors?['monthlyRisk'] ?? false;

        // Send notifications for at-risk status
        if (monthlyRisk) {
          // Send critical monthly risk notification
          final monthlyAbsences = atRiskData['monthlyAbsences'] ?? 0;
          final monthlyWeekdays = atRiskData['monthlyWeekdays'] ?? 0;
          final monthlyPresent = monthlyWeekdays - monthlyAbsences;
          final monthlyRate = monthlyWeekdays > 0
              ? ((monthlyPresent / monthlyWeekdays) * 100).round()
              : 100;

          _sendAtRiskNotification(
            riskType: 'monthly',
            title: 'CRITICAL: Monthly Attendance Risk',
            body:
                'Your attendance is at $monthlyRate% this month. Please contact your instructor immediately. A suspension may be imposed if no action is taken.',
          );

          return _buildMonthlyAtRiskBanner(context, atRiskData);
        } else if (weeklyRisk) {
          // Send weekly risk notification
          final weeklyAbsences = atRiskData['weeklyAbsences'] ?? 0;
          final weeklyWeekdays = atRiskData['weeklyWeekdays'] ?? 0;
          final weeklyPresent = weeklyWeekdays - weeklyAbsences;
          final weeklyRate = weeklyWeekdays > 0
              ? ((weeklyPresent / weeklyWeekdays) * 100).round()
              : 100;

          _sendAtRiskNotification(
            riskType: 'weekly',
            title: 'Weekly Attendance Risk Alert',
            body:
                'Your attendance is at $weeklyRate% this week. You have $weeklyAbsences absences. Please contact your instructor/school for follow-up or actions will be taken.',
          );

          return _buildWeeklyAtRiskBanner(context, atRiskData);
        }

        return SizedBox.shrink();
      },
    );
  }

  Widget _buildWeeklyAtRiskBanner(
    BuildContext context,
    Map<String, dynamic> atRiskData,
  ) {
    // Get data from the at-risk calculation
    final weeklyAbsences = atRiskData['weeklyAbsences'] ?? 0;
    final weeklyWeekdays = atRiskData['weeklyWeekdays'] ?? 0;
    final weeklyPresent = weeklyWeekdays - weeklyAbsences;
    final weeklyRate = weeklyWeekdays > 0
        ? ((weeklyPresent / weeklyWeekdays) * 100).round()
        : 100;

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
            color: Colors.orange.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.calendar_view_week_outlined,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Attendance Risk',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'This week: $weeklyPresent/$weeklyWeekdays days ($weeklyRate%). You have $weeklyAbsences absences. please contact your instructor/school for follow-up or actions will be taken.',
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
              onPressed: () {
                // Navigate to attendance page or dismiss
              },
              child: Text(
                'View',
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

  Widget _buildMonthlyAtRiskBanner(
    BuildContext context,
    Map<String, dynamic> atRiskData,
  ) {
    // Get data from the at-risk calculation
    final monthlyAbsences = atRiskData['monthlyAbsences'] ?? 0;
    final monthlyWeekdays = atRiskData['monthlyWeekdays'] ?? 0;
    final monthlyPresent = monthlyWeekdays - monthlyAbsences;
    final monthlyRate = monthlyWeekdays > 0
        ? ((monthlyPresent / monthlyWeekdays) * 100).round()
        : 100;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
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
                    Icons.calendar_month_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'CRITICAL: Monthly Attendance Risk',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Last 30 days: $monthlyPresent/$monthlyWeekdays days ($monthlyRate%). You have $monthlyAbsences absences. Contact your instructor/school for follow-up.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}