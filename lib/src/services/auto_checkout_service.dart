/// Auto Checkout Service
///
/// Comprehensive system for automatically checking out students at 4 PM
/// with complete attendance recording and geofence validation.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/notification_service.dart';
import '../features/geofence/geofence_service.dart';

class AutoCheckoutService {
  static final AutoCheckoutService _instance = AutoCheckoutService._internal();
  factory AutoCheckoutService() => _instance;
  AutoCheckoutService._internal();

  static AutoCheckoutService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Timer? _dailyTimer;
  bool _isServiceRunning = false;
  StreamSubscription<QuerySnapshot>? _activeStudentsSubscription;

  /// Initialize the auto-checkout service
  Future<void> initialize() async {
    if (_isServiceRunning) {
      print('🔄 Auto-checkout service already running');
      return;
    }

    try {
      await _initializeNotifications();
      await _setupDailyTimer();
      await _monitorActiveStudents();

      _isServiceRunning = true;
      print('✅ Auto-checkout service initialized successfully');

      // Log service start
      await _logAutoCheckoutEvent('service_started', {
        'timestamp': FieldValue.serverTimestamp(),
        'action': 'Auto-checkout service initialized',
      });
    } catch (e) {
      print('❌ Error initializing auto-checkout service: $e');
      await _logAutoCheckoutEvent('service_error', {
        'error': e.toString(),
        'action': 'Failed to initialize auto-checkout service',
      });
    }
  }

  /// Setup daily timer for 4 PM auto-checkout
  Future<void> _setupDailyTimer() async {
    // Cancel existing timer if any
    _dailyTimer?.cancel();

    final now = DateTime.now();
    final targetTime = DateTime(
      now.year,
      now.month,
      now.day,
      16,
      0,
      0,
    ); // 4:00 PM
    DateTime nextExecution = targetTime;

    // If it's already past 4 PM today, schedule for tomorrow
    if (now.isAfter(targetTime)) {
      nextExecution = targetTime.add(const Duration(days: 1));
    }

    final duration = nextExecution.difference(now);

    print('⏰ Auto-checkout scheduled for: ${nextExecution.toString()}');
    print('⏱️  Time until next execution: ${duration.toString()}');

    _dailyTimer = Timer(duration, () async {
      await _performDailyAutoCheckout();
      // Reschedule for next day
      await _setupDailyTimer();
    });

    await _logAutoCheckoutEvent('timer_scheduled', {
      'next_execution': Timestamp.fromDate(nextExecution),
      'duration_minutes': duration.inMinutes,
    });
  }

  /// Initialize local notifications for auto-checkout alerts
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initializationSettings);
  }

  /// Monitor active students who need auto-checkout
  Future<void> _monitorActiveStudents() async {
    // Listen for students who are currently checked in
    _activeStudentsSubscription?.cancel();

    final today = DateTime.now();
    final dateId = _formatDateId(today);

    _activeStudentsSubscription = _firestore
        .collectionGroup('days')
        .where('dayId', isEqualTo: dateId)
        .where('inAt', isNotEqualTo: null) // Has checked in
        .where('outAt', isEqualTo: null) // Has not checked out
        .snapshots()
        .listen((snapshot) {
          final activeCount = snapshot.docs.length;
          print('👥 Active students (checked in, not out): $activeCount');

          // Log active student count periodically
          _logAutoCheckoutEvent('active_students_count', {
            'count': activeCount,
            'date': dateId,
          });
        });
  }

  /// Perform daily auto-checkout for all active students
  Future<void> _performDailyAutoCheckout() async {
    final startTime = DateTime.now();
    print('🏁 Starting daily auto-checkout at ${startTime.toString()}');

    try {
      // Get all students who are checked in but not checked out
      final today = DateTime.now();
      final dateId = _formatDateId(today);

      final activeStudentsSnapshot = await _firestore
          .collectionGroup('days')
          .where('dayId', isEqualTo: dateId)
          .where('inAt', isNotEqualTo: null)
          .where('outAt', isEqualTo: null)
          .get();

      final activeStudents = activeStudentsSnapshot.docs;
      print('📊 Found ${activeStudents.length} students to auto-checkout');

      if (activeStudents.isEmpty) {
        await _logAutoCheckoutEvent('no_students', {
          'message': 'No students required auto-checkout',
          'date': dateId,
        });
        return;
      }

      int successCount = 0;
      int failureCount = 0;
      final List<Map<String, dynamic>> processingResults = [];

      // Process each student
      for (final doc in activeStudents) {
        final userId = doc.reference.parent.parent?.id;
        if (userId == null) continue;

        try {
          final result = await _autoCheckoutStudent(userId, dateId);
          if (result['success']) {
            successCount++;
          } else {
            failureCount++;
          }
          processingResults.add({
            'userId': userId,
            'success': result['success'],
            'message': result['message'],
            'timestamp': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          failureCount++;
          processingResults.add({
            'userId': userId,
            'success': false,
            'error': e.toString(),
            'timestamp': FieldValue.serverTimestamp(),
          });
          print('❌ Error auto-checking out student $userId: $e');
        }

        // Small delay between students to avoid overwhelming the system
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      // Log comprehensive results
      await _logAutoCheckoutEvent('daily_completion', {
        'total_students': activeStudents.length,
        'success_count': successCount,
        'failure_count': failureCount,
        'duration_seconds': duration.inSeconds,
        'start_time': Timestamp.fromDate(startTime),
        'end_time': Timestamp.fromDate(endTime),
        'date': dateId,
        'results': processingResults,
      });

      // Send notification to admins
      await _notifyAdminsAutoCheckoutComplete(
        successCount,
        failureCount,
        activeStudents.length,
      );

      print(
        '✅ Auto-checkout completed: $successCount successful, $failureCount failed',
      );
    } catch (e) {
      print('❌ Critical error during daily auto-checkout: $e');
      await _logAutoCheckoutEvent('critical_error', {
        'error': e.toString(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Auto-checkout individual student with complete validation
  Future<Map<String, dynamic>> _autoCheckoutStudent(
    String userId,
    String dateId,
  ) async {
    try {
      print('🔄 Processing auto-checkout for user: $userId');

      // Get user information
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {'success': false, 'message': 'User document not found'};
      }

      final userData = userDoc.data()!;
      final userName =
          '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();

      // Get current attendance record
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc(userId)
          .collection('days')
          .doc(dateId)
          .get();

      if (!attendanceDoc.exists || attendanceDoc.data()?['inAt'] == null) {
        return {
          'success': false,
          'message': 'No check-in record found for $userName',
        };
      }

      final attendanceData = attendanceDoc.data()!;
      if (attendanceData['outAt'] != null) {
        return {'success': false, 'message': '$userName already checked out'};
      }

      // Get current location or use default location
      Position? currentPosition;
      try {
        currentPosition = await _getCurrentLocationWithTimeout();
      } catch (e) {
        print('⚠️  Could not get location for $userName, using default: $e');
        // Use default location or last known location
        currentPosition = await _getDefaultOrLastKnownLocation(userId);
      }

      // Validate against geofence if position is available
      String checkoutMessage = 'Auto-checkout at 4:00 PM';
      bool geofenceValidated = false;
      double? geofenceDistance;

      if (currentPosition != null) {
        try {
          final validation = await GeofenceService.instance.validateLocation(
            'checkout',
          );

          geofenceValidated = validation.isValid;
          geofenceDistance = validation.distance;

          if (!validation.isValid) {
            checkoutMessage +=
                ' (Outside geofence: ${validation.distance.toStringAsFixed(0)}m)';

            // Create geofence incident for auto-checkout outside boundary
            await _createAutoCheckoutIncident(
              userId,
              userName,
              currentPosition,
              validation,
            );
          }
        } catch (e) {
          print('⚠️  Geofence validation failed for $userName: $e');
          checkoutMessage += ' (Geofence validation unavailable)';
        }
      } else {
        checkoutMessage += ' (Location unavailable)';
      }

      // Get place name
      String placeName = 'Auto-checkout location';
      if (currentPosition != null) {
        try {
          // You would implement place name resolution here
          placeName = await _getPlaceName(currentPosition);
        } catch (e) {
          print('⚠️  Could not resolve place name: $e');
        }
      }

      // Update attendance record
      final now = DateTime.now();
      final updateData = <String, dynamic>{
        'outAt': Timestamp.fromDate(now),
        'outPlace': placeName,
        'autoCheckout': true,
        'autoCheckoutTime': Timestamp.fromDate(now),
        'autoCheckoutMessage': checkoutMessage,
        'updatedAt': Timestamp.fromDate(now),
      };

      if (currentPosition != null) {
        updateData['outLat'] = currentPosition.latitude;
        updateData['outLng'] = currentPosition.longitude;
      }

      if (geofenceDistance != null) {
        updateData['outGeofenceDistance'] = geofenceDistance;
        updateData['outGeofenceValidated'] = geofenceValidated;
      }

      await attendanceDoc.reference.update(updateData);

      // Send notification to student
      await _notifyStudentAutoCheckout(userId, userName, checkoutMessage);

      // Log individual checkout
      await _logAutoCheckoutEvent('student_checkout', {
        'userId': userId,
        'userName': userName,
        'geofenceValidated': geofenceValidated,
        'geofenceDistance': geofenceDistance,
        'placeName': placeName,
        'hasLocation': currentPosition != null,
      });

      return {
        'success': true,
        'message': '$userName auto-checked out successfully',
        'geofenceValidated': geofenceValidated,
        'distance': geofenceDistance,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Auto-checkout failed: $e',
        'error': e.toString(),
      };
    }
  }

  /// Get current location with timeout
  Future<Position?> _getCurrentLocationWithTimeout() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('⚠️  Location timeout or error: $e');
      return null;
    }
  }

  /// Get default or last known location for a user
  Future<Position?> _getDefaultOrLastKnownLocation(String userId) async {
    try {
      // Try to get last known location from recent attendance records
      final recentAttendance = await _firestore
          .collection('attendance')
          .doc(userId)
          .collection('days')
          .orderBy('dayId', descending: true)
          .limit(5)
          .get();

      for (final doc in recentAttendance.docs) {
        final data = doc.data();
        final lat = data['inLat'] ?? data['outLat'];
        final lng = data['inLng'] ?? data['outLng'];

        if (lat != null && lng != null) {
          print('📍 Using last known location for user $userId');
          return Position(
            latitude: lat.toDouble(),
            longitude: lng.toDouble(),
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        }
      }

      // Fallback to campus default location if available
      return await _getCampusDefaultLocation(userId);
    } catch (e) {
      print('⚠️  Could not get default location: $e');
      return null;
    }
  }

  /// Get campus default location for user
  Future<Position?> _getCampusDefaultLocation(String userId) async {
    try {
      // You would implement campus location logic here
      // For now, return null to indicate no default available
      return null;
    } catch (e) {
      print('⚠️  Could not get campus location: $e');
      return null;
    }
  }

  /// Create geofence incident for auto-checkout outside boundary
  Future<void> _createAutoCheckoutIncident(
    String userId,
    String userName,
    Position position,
    dynamic validation,
  ) async {
    try {
      await _firestore.collection('geofence_incidents').add({
        'studentId': userId,
        'studentName': userName,
        'direction': 'check_out',
        'occurredAt': Timestamp.now(),
        'distance': validation.distance,
        'designatedLocation': {
          'lat': validation.targetLat ?? 0.0,
          'lng': validation.targetLng ?? 0.0,
        },
        'actualLocation': {'lat': position.latitude, 'lng': position.longitude},
        'bandType': 'auto_checkout',
        'status': 'pending',
        'messageText': 'Auto-checkout at 4:00 PM - Outside geofence boundary',
        'createdAt': Timestamp.now(),
        'autoGenerated': true,
      });

      print('📝 Created geofence incident for auto-checkout: $userName');
    } catch (e) {
      print('❌ Error creating geofence incident: $e');
    }
  }

  /// Get place name from position
  Future<String> _getPlaceName(Position position) async {
    try {
      // You would implement geocoding here
      // For now, return a formatted location string
      return 'Auto-checkout (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
    } catch (e) {
      return 'Auto-checkout location';
    }
  }

  /// Notify student of auto-checkout
  Future<void> _notifyStudentAutoCheckout(
    String userId,
    String userName,
    String message,
  ) async {
    try {
      // Get user's FCM token and send push notification
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final fcmToken = userData?['fcmToken'] as String?;

      if (fcmToken != null) {
        await NotificationService.sendPushNotification(
          deviceToken: fcmToken,
          title: 'Auto-Checkout Complete',
          body: 'You have been automatically checked out at 4:00 PM. $message',
        );
      }

      // Store notification in Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'title': 'Auto-Checkout Complete',
            'message':
                'You have been automatically checked out at 4:00 PM. $message',
            'type': 'auto_checkout',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      print('📱 Notified $userName of auto-checkout');
    } catch (e) {
      print('❌ Error notifying student: $e');
    }
  }

  /// Notify admins of auto-checkout completion
  Future<void> _notifyAdminsAutoCheckoutComplete(
    int successCount,
    int failureCount,
    int totalCount,
  ) async {
    try {
      final message =
          'Auto-checkout completed: $successCount/$totalCount successful';

      // Get all admin users
      final adminsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (final doc in adminsSnapshot.docs) {
        final adminId = doc.id;
        final adminData = doc.data();
        final fcmToken = adminData['fcmToken'] as String?;

        // Send push notification if admin has FCM token
        if (fcmToken != null) {
          await NotificationService.sendPushNotification(
            deviceToken: fcmToken,
            title: 'Daily Auto-Checkout Complete',
            body: message,
          );
        }

        // Store admin notification
        await _firestore
            .collection('users')
            .doc(adminId)
            .collection('notifications')
            .add({
              'title': 'Daily Auto-Checkout Complete',
              'message': message,
              'type': 'admin_auto_checkout_report',
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
              'details': {
                'success_count': successCount,
                'failure_count': failureCount,
                'total_count': totalCount,
              },
            });
      }

      print('📧 Notified admins of auto-checkout completion');
    } catch (e) {
      print('❌ Error notifying admins: $e');
    }
  }

  /// Log auto-checkout events for monitoring
  Future<void> _logAutoCheckoutEvent(
    String eventType,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection('auto_checkout_logs').add({
        'eventType': eventType,
        'timestamp': FieldValue.serverTimestamp(),
        'data': data,
      });
    } catch (e) {
      print('❌ Error logging auto-checkout event: $e');
    }
  }

  /// Format date to string for Firestore document IDs
  String _formatDateId(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Manual trigger for testing auto-checkout
  Future<Map<String, dynamic>> triggerManualAutoCheckout() async {
    print('🧪 Manually triggering auto-checkout for testing');

    final startTime = DateTime.now();
    await _performDailyAutoCheckout();
    final endTime = DateTime.now();

    return {
      'success': true,
      'message': 'Manual auto-checkout completed',
      'duration': endTime.difference(startTime).inSeconds,
      'timestamp': endTime.toIso8601String(),
    };
  }

  /// Get auto-checkout statistics
  Future<Map<String, dynamic>> getAutoCheckoutStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final end = endDate ?? DateTime.now();

      final logsSnapshot = await _firestore
          .collection('auto_checkout_logs')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('timestamp', descending: true)
          .get();

      int totalEvents = 0;
      int dailyCompletions = 0;
      int totalStudentsProcessed = 0;
      int totalSuccessful = 0;
      int totalFailed = 0;

      for (final doc in logsSnapshot.docs) {
        final data = doc.data();
        final eventType = data['eventType'] as String;
        totalEvents++;

        if (eventType == 'daily_completion') {
          dailyCompletions++;
          final eventData = data['data'] as Map<String, dynamic>? ?? {};
          totalStudentsProcessed += (eventData['total_students'] as int? ?? 0);
          totalSuccessful += (eventData['success_count'] as int? ?? 0);
          totalFailed += (eventData['failure_count'] as int? ?? 0);
        }
      }

      return {
        'period': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
        'totals': {
          'events': totalEvents,
          'daily_completions': dailyCompletions,
          'students_processed': totalStudentsProcessed,
          'successful_checkouts': totalSuccessful,
          'failed_checkouts': totalFailed,
        },
        'success_rate': totalStudentsProcessed > 0
            ? (totalSuccessful / totalStudentsProcessed * 100).toStringAsFixed(
                1,
              )
            : '0.0',
        'service_running': _isServiceRunning,
        'next_execution': _dailyTimer != null ? 'Scheduled' : 'Not scheduled',
      };
    } catch (e) {
      return {'error': e.toString(), 'service_running': _isServiceRunning};
    }
  }

  /// Stop the auto-checkout service
  Future<void> stopService() async {
    print('🛑 Stopping auto-checkout service');

    _dailyTimer?.cancel();
    _dailyTimer = null;

    _activeStudentsSubscription?.cancel();
    _activeStudentsSubscription = null;

    _isServiceRunning = false;

    await _logAutoCheckoutEvent('service_stopped', {
      'timestamp': FieldValue.serverTimestamp(),
      'action': 'Auto-checkout service stopped manually',
    });

    print('✅ Auto-checkout service stopped');
  }

  /// Dispose resources
  void dispose() {
    stopService();
  }
}
