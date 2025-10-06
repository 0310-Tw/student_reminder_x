/// Enhanced Checkout Service
///
/// Comprehensive service to handle manual and automatic checkout operations
/// with proper geofence validation and permission management.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../features/geofence/geofence_service.dart';

class CheckoutService {
  static final CheckoutService _instance = CheckoutService._internal();
  factory CheckoutService() => _instance;
  CheckoutService._internal();

  static CheckoutService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Perform checkout with comprehensive validation
  Future<CheckoutResult> performCheckout({
    String? studentId,
    bool isAutoCheckout = false,
    String? customMessage,
    Position? customPosition,
  }) async {
    try {
      // Get user ID (use current user if not specified)
      final user = AuthService.instance.currentUser;
      final userId = studentId ?? user?.uid;

      if (userId == null) {
        return CheckoutResult(
          success: false,
          message: 'User not authenticated',
          errorType: CheckoutErrorType.authentication,
        );
      }

      // Get current position
      Position? currentPosition = customPosition;
      if (currentPosition == null) {
        try {
          currentPosition = await _getCurrentPosition();
        } catch (e) {
          if (!isAutoCheckout) {
            return CheckoutResult(
              success: false,
              message: 'Unable to get current location: $e',
              errorType: CheckoutErrorType.location,
            );
          }
          // For auto-checkout, continue without location
        }
      }

      // Get today's date ID
      final now = DateTime.now();
      final dateId = _formatDateId(now);

      // Check if user is already checked out
      final existingRecord = await _firestore
          .collection('attendance')
          .doc(userId)
          .collection('days')
          .doc(dateId)
          .get();

      if (!existingRecord.exists || existingRecord.data()?['inAt'] == null) {
        return CheckoutResult(
          success: false,
          message: 'Cannot checkout - no check-in record found',
          errorType: CheckoutErrorType.noCheckin,
        );
      }

      final attendanceData = existingRecord.data()!;
      if (attendanceData['outAt'] != null) {
        return CheckoutResult(
          success: false,
          message: 'Already checked out',
          errorType: CheckoutErrorType.alreadyCheckedOut,
        );
      }

      // Validate geofence if location is available
      GeofenceValidationResult? geofenceResult;
      if (currentPosition != null) {
        try {
          geofenceResult = await GeofenceService.instance.validateLocation(
            'checkout',
          );
        } catch (e) {
          print('⚠️  Geofence validation error: $e');
          // Continue without geofence validation for auto-checkout
          if (!isAutoCheckout) {
            return CheckoutResult(
              success: false,
              message: 'Geofence validation failed: $e',
              errorType: CheckoutErrorType.geofence,
            );
          }
        }
      }

      // Get place name
      String placeName = 'Unknown location';
      if (currentPosition != null) {
        try {
          placeName = await _getPlaceName(currentPosition);
        } catch (e) {
          placeName = isAutoCheckout
              ? 'Auto-checkout location'
              : 'Manual checkout location';
        }
      }

      // Prepare checkout data
      final checkoutData = <String, dynamic>{
        'outAt': Timestamp.fromDate(now),
        'outPlace': placeName,
        'updatedAt': Timestamp.fromDate(now),
      };

      if (currentPosition != null) {
        checkoutData['outLat'] = currentPosition.latitude;
        checkoutData['outLng'] = currentPosition.longitude;
      }

      if (isAutoCheckout) {
        checkoutData['autoCheckout'] = true;
        checkoutData['autoCheckoutTime'] = Timestamp.fromDate(now);
        checkoutData['autoCheckoutMessage'] =
            customMessage ?? 'Auto-checkout at 4:00 PM';
      }

      if (geofenceResult != null) {
        checkoutData['outGeofenceDistance'] = geofenceResult.distance;
        checkoutData['outGeofenceValidated'] = geofenceResult.isValid;

        // Handle geofence violations
        if (!geofenceResult.isValid) {
          await _handleGeofenceViolation(
            userId,
            currentPosition!,
            geofenceResult,
            isAutoCheckout,
          );

          // For manual checkout, respect geofence policy
          if (!isAutoCheckout) {
            final profile = await GeofenceService.instance
                .getTodayGeofenceProfile(userId);
            final outsidePolicy = profile['outsidePolicy'] ?? 'block';

            if (outsidePolicy == 'block') {
              return CheckoutResult(
                success: false,
                message:
                    'Checkout blocked - outside designated area (${geofenceResult.distance.toStringAsFixed(0)}m away)',
                errorType: CheckoutErrorType.geofenceBlocked,
                distance: geofenceResult.distance,
              );
            }
          }
        }
      }

      // Update attendance record
      await existingRecord.reference.update(checkoutData);

      // Create attendance record for at-risk calculations if needed
      await _createAttendanceRecord(userId, now, attendanceData, checkoutData);

      // Log checkout event
      await _logCheckoutEvent(userId, isAutoCheckout, geofenceResult);

      return CheckoutResult(
        success: true,
        message: isAutoCheckout
            ? 'Auto-checkout completed successfully'
            : 'Checkout completed successfully',
        distance: geofenceResult?.distance,
        geofenceValidated: geofenceResult?.isValid,
        placeName: placeName,
      );
    } catch (e) {
      print('❌ Checkout error: $e');
      return CheckoutResult(
        success: false,
        message: 'Checkout failed: $e',
        errorType: CheckoutErrorType.system,
        error: e.toString(),
      );
    }
  }

  /// Get current position with timeout and permission handling
  Future<Position> _getCurrentPosition() async {
    // Check location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    // Check if location service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
  }

  /// Handle geofence violations during checkout
  Future<void> _handleGeofenceViolation(
    String userId,
    Position position,
    GeofenceValidationResult geofenceResult,
    bool isAutoCheckout,
  ) async {
    try {
      // Get user information
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      final userName =
          '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();

      // Create geofence incident
      await _firestore.collection('geofence_incidents').add({
        'studentId': userId,
        'studentName': userName,
        'direction': 'check_out',
        'occurredAt': Timestamp.now(),
        'distance': geofenceResult.distance,
        'designatedLocation': {
          'lat': 0.0, // Will be populated from geofence profile
          'lng': 0.0, // Will be populated from geofence profile
        },
        'actualLocation': {'lat': position.latitude, 'lng': position.longitude},
        'bandType': 'fixed', // Default to fixed for incidents
        'status': 'pending',
        'messageText': isAutoCheckout
            ? 'Auto-checkout outside geofence boundary'
            : 'Manual checkout outside geofence boundary',
        'createdAt': Timestamp.now(),
        'autoGenerated': isAutoCheckout,
      });

      print('📝 Created geofence incident for checkout violation: $userName');
    } catch (e) {
      print('❌ Error creating geofence incident: $e');
    }
  }

  /// Create attendance record for at-risk calculations
  Future<void> _createAttendanceRecord(
    String userId,
    DateTime checkoutTime,
    Map<String, dynamic> checkinData,
    Map<String, dynamic> checkoutData,
  ) async {
    try {
      final dateId = _formatDateId(checkoutTime);

      // Calculate total hours worked
      final checkinTimestamp = checkinData['inAt'] as Timestamp?;
      double? hoursWorked;

      if (checkinTimestamp != null) {
        final checkinTime = checkinTimestamp.toDate();
        final duration = checkoutTime.difference(checkinTime);
        hoursWorked = duration.inMinutes / 60.0;
      }

      // Create or update attendance record
      await _firestore
          .collection('attendance_records')
          .doc('${userId}_$dateId')
          .set({
            'studentId': userId,
            'date': dateId,
            'checkinTime': checkinData['inAt'],
            'checkoutTime': checkoutData['outAt'],
            'status': checkinData['status'] ?? 'present',
            'hoursWorked': hoursWorked,
            'checkinLocation': {
              'lat': checkinData['inLat'],
              'lng': checkinData['inLng'],
              'place': checkinData['placeIn'],
            },
            'checkoutLocation': {
              'lat': checkoutData['outLat'],
              'lng': checkoutData['outLng'],
              'place': checkoutData['outPlace'],
            },
            'geofenceValidated': {
              'checkin': checkinData['inGeofenceValidated'] ?? false,
              'checkout': checkoutData['outGeofenceValidated'] ?? false,
            },
            'autoCheckout': checkoutData['autoCheckout'] ?? false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('⚠️  Could not create attendance record: $e');
      // Don't fail checkout for this error
    }
  }

  /// Log checkout events for monitoring
  Future<void> _logCheckoutEvent(
    String userId,
    bool isAutoCheckout,
    GeofenceValidationResult? geofenceResult,
  ) async {
    try {
      await _firestore.collection('checkout_logs').add({
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': isAutoCheckout ? 'auto_checkout' : 'manual_checkout',
        'geofenceValidated': geofenceResult?.isValid,
        'geofenceDistance': geofenceResult?.distance,
        'success': true,
      });
    } catch (e) {
      print('⚠️  Could not log checkout event: $e');
    }
  }

  /// Get place name from coordinates
  Future<String> _getPlaceName(Position position) async {
    try {
      // You would implement actual geocoding here
      // For now, return formatted coordinates
      return 'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
    } catch (e) {
      return 'Unknown location';
    }
  }

  /// Format date to YYYY-MM-DD format
  String _formatDateId(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if user can checkout (has checked in and not checked out)
  Future<CheckoutEligibility> checkCheckoutEligibility([String? userId]) async {
    try {
      final user = AuthService.instance.currentUser;
      final targetUserId = userId ?? user?.uid;

      if (targetUserId == null) {
        return CheckoutEligibility(
          eligible: false,
          reason: 'User not authenticated',
        );
      }

      final now = DateTime.now();
      final dateId = _formatDateId(now);

      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc(targetUserId)
          .collection('days')
          .doc(dateId)
          .get();

      if (!attendanceDoc.exists) {
        return CheckoutEligibility(
          eligible: false,
          reason: 'No attendance record for today',
        );
      }

      final data = attendanceDoc.data()!;

      if (data['inAt'] == null) {
        return CheckoutEligibility(
          eligible: false,
          reason: 'Not checked in yet',
        );
      }

      if (data['outAt'] != null) {
        return CheckoutEligibility(
          eligible: false,
          reason: 'Already checked out',
        );
      }

      return CheckoutEligibility(
        eligible: true,
        checkinTime: (data['inAt'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      return CheckoutEligibility(
        eligible: false,
        reason: 'Error checking eligibility: $e',
      );
    }
  }
}

/// Result of checkout operation
class CheckoutResult {
  final bool success;
  final String message;
  final CheckoutErrorType? errorType;
  final String? error;
  final double? distance;
  final bool? geofenceValidated;
  final String? placeName;

  const CheckoutResult({
    required this.success,
    required this.message,
    this.errorType,
    this.error,
    this.distance,
    this.geofenceValidated,
    this.placeName,
  });

  @override
  String toString() {
    return 'CheckoutResult(success: $success, message: $message, errorType: $errorType)';
  }
}

/// Checkout error types for better error handling
enum CheckoutErrorType {
  authentication,
  location,
  noCheckin,
  alreadyCheckedOut,
  geofence,
  geofenceBlocked,
  system,
}

/// Checkout eligibility check result
class CheckoutEligibility {
  final bool eligible;
  final String? reason;
  final DateTime? checkinTime;

  const CheckoutEligibility({
    required this.eligible,
    this.reason,
    this.checkinTime,
  });

  @override
  String toString() {
    return 'CheckoutEligibility(eligible: $eligible, reason: $reason)';
  }
}
