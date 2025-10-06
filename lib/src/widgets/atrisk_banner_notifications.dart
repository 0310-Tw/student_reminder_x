import 'dart:async';
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
  // Static variables to persist across all instances
  static final Map<String, String> _lastNotificationsSent = {};
  static final Map<String, bool> _notificationsSending = {};

  // Debounce timer to prevent rapid fire notifications
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _cleanupOldNotificationCache();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Clean up old notification cache entries to prevent memory buildup
  Future<void> _cleanupOldNotificationCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final today = DateTime.now();
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Remove notification keys that are older than today
      for (final key in keys) {
        if (key.startsWith('last_notification_')) {
          final value = prefs.getString(key);
          if (value != null && value != todayKey) {
            await prefs.remove(key);
          }
        }
      }

      // Clean up static cache
      _lastNotificationsSent.removeWhere((key, value) => value != todayKey);
      _notificationsSending.clear(); // Clear sending flags on init
    } catch (e) {
      print('Error cleaning notification cache: $e');
    }
  }

  /// Get stream of at-risk status by calculating real-time attendance data
  /// This ensures accurate at-risk detection for the current week/month
  Stream<Map<String, dynamic>> _getAtRiskStatusStream(String userId) {
    return FirebaseFirestore.instance
        .collection('attendance_records')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: _getStartOfMonth())
        .orderBy('date', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          return await _calculateAtRiskStatus(userId, snapshot.docs);
        });
  }

  /// Get the start of the current month
  DateTime _getStartOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Get the start of the current week (Monday)
  DateTime _getStartOfWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
  }

  /// Calculate real-time at-risk status based on actual attendance data
  Future<Map<String, dynamic>> _calculateAtRiskStatus(
    String userId,
    List<QueryDocumentSnapshot> attendanceRecords,
  ) async {
    final now = DateTime.now();
    final startOfWeek = _getStartOfWeek();

    // Count weekdays in current week and month (excluding weekends)
    int weeklyWeekdays = 0;
    int monthlyWeekdays = 0;

    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      if (day.weekday >= 1 &&
          day.weekday <= 5 &&
          day.isBefore(now.add(Duration(days: 1)))) {
        weeklyWeekdays++;
      }
    }

    for (int i = 1; i <= now.day; i++) {
      final day = DateTime(now.year, now.month, i);
      if (day.weekday >= 1 && day.weekday <= 5) {
        monthlyWeekdays++;
      }
    }

    // Count actual attendance (present days)
    int weeklyPresent = 0;
    int monthlyPresent = 0;

    for (final record in attendanceRecords) {
      final data = record.data() as Map<String, dynamic>;
      final date = (data['date'] as Timestamp).toDate();
      final isPresent = data['isPresent'] as bool? ?? false;

      if (isPresent && date.weekday >= 1 && date.weekday <= 5) {
        // Only count weekdays
        if (date.isAfter(startOfWeek.subtract(Duration(days: 1)))) {
          weeklyPresent++;
        }
        monthlyPresent++;
      }
    }

    // Calculate absence counts and rates
    final weeklyAbsences = weeklyWeekdays - weeklyPresent;
    final monthlyAbsences = monthlyWeekdays - monthlyPresent;

    final weeklyRate = weeklyWeekdays > 0
        ? (weeklyPresent / weeklyWeekdays) * 100
        : 100.0;
    final monthlyRate = monthlyWeekdays > 0
        ? (monthlyPresent / monthlyWeekdays) * 100
        : 100.0;

    // At-risk thresholds
    const weeklyThreshold = 80.0; // 80% attendance required per week
    const monthlyThreshold = 85.0; // 85% attendance required per month

    final weeklyRisk =
        weeklyRate < weeklyThreshold &&
        weeklyWeekdays >= 3; // Only flag if at least 3 weekdays have passed
    final monthlyRisk =
        monthlyRate < monthlyThreshold &&
        monthlyWeekdays >= 10; // Only flag if at least 10 weekdays have passed

    return {
      'isAtRisk': weeklyRisk || monthlyRisk,
      'weeklyAbsences': weeklyAbsences,
      'weeklyWeekdays': weeklyWeekdays,
      'weeklyPresent': weeklyPresent,
      'weeklyRate': weeklyRate,
      'monthlyAbsences': monthlyAbsences,
      'monthlyWeekdays': monthlyWeekdays,
      'monthlyPresent': monthlyPresent,
      'monthlyRate': monthlyRate,
      'riskFactors': {'weeklyRisk': weeklyRisk, 'monthlyRisk': monthlyRisk},
      'lastCalculated': Timestamp.now(),
    };
  }

  /// Debounced wrapper for sending notifications
  void _sendAtRiskNotificationDebounced({
    required String riskType,
    required String title,
    required String body,
  }) {
    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Set a new timer to send notification after 2 seconds
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _sendAtRiskNotification(riskType: riskType, title: title, body: body);
    });
  }

  /// Send push notification for at-risk status
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

    // Check if we're already sending this notification
    if (_notificationsSending[notificationKey] == true) {
      print('Notification already sending for: $notificationKey');
      return;
    }

    // Check if we already sent this notification today (using SharedPreferences for persistence)
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
      _notificationsSending[notificationKey] = true;
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
    } finally {
      _notificationsSending[notificationKey] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) return SizedBox.shrink();

    return StreamBuilder<Map<String, dynamic>>(
      stream: _getAtRiskStatusStream(user.uid),
      builder: (context, snapshot) {
        // Handle errors or loading states
        if (snapshot.hasError) {
          print('AtRiskBannerNotifications error: ${snapshot.error}');
          return SizedBox.shrink();
        }

        if (!snapshot.hasData ||
            snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox.shrink();
        }

        final atRiskData = snapshot.data!;
        if (atRiskData.isEmpty) return SizedBox.shrink();

        final isAtRisk = atRiskData['isAtRisk'] ?? false;
        if (!isAtRisk) return SizedBox.shrink();

        // Get risk factors to determine which banner to show
        final riskFactors = atRiskData['riskFactors'] as Map<String, dynamic>?;
        final weeklyRisk = riskFactors?['weeklyRisk'] ?? false;
        final monthlyRisk = riskFactors?['monthlyRisk'] ?? false;

        // Send notifications for at-risk status (only when conditions are met)
        if (monthlyRisk) {
          // Send critical monthly risk notification
          final monthlyWeekdays = atRiskData['monthlyWeekdays'] ?? 0;
          final monthlyRate = (atRiskData['monthlyRate'] ?? 100.0).round();

          // Only send notification if we have enough data to make an assessment
          if (monthlyWeekdays >= 10) {
            _sendAtRiskNotificationDebounced(
              riskType: 'monthly',
              title: 'CRITICAL: Monthly Attendance Risk',
              body:
                  'Your attendance is at $monthlyRate% this month. Please contact your instructor immediately. A suspension may be imposed if no action is taken.',
            );
          }

          return _buildMonthlyAtRiskBanner(context, atRiskData);
        } else if (weeklyRisk) {
          // Send weekly risk notification
          final weeklyWeekdays = atRiskData['weeklyWeekdays'] ?? 0;
          final weeklyRate = (atRiskData['weeklyRate'] ?? 100.0).round();

          // Only send notification if we have enough data to make an assessment
          if (weeklyWeekdays >= 3) {
            final weeklyAbsences = atRiskData['weeklyAbsences'] ?? 0;
            _sendAtRiskNotificationDebounced(
              riskType: 'weekly',
              title: 'Weekly Attendance Risk Alert',
              body:
                  'Your attendance is at $weeklyRate% this week. You have $weeklyAbsences absences. Please contact your instructor/school for follow-up or actions will be taken.',
            );
          }

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
