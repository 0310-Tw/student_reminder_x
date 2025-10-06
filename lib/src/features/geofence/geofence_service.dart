import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/admin/models/geofence_model.dart';

import 'campus_location_service.dart';

class GeofenceService {
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;
  GeofenceService._internal();

  // Also provide instance accessor for compatibility with existing code
  static GeofenceService get instance => _instance;

  /// Get campus location by ID
  CampusLocation? getCampusLocation(String campusId) {
    return _campusService.getCampusLocation(campusId);
  }

  /// Create geofence profile from campus location
  Map<String, dynamic> createProfileFromCampus(
    String campusId, {
    String bandType = 'fixed',
    String outsidePolicy = 'allow',
    String? outsideMessage,
  }) {
    return _campusService.createGeofenceProfileFromCampus(
      campusId,
      bandType: bandType,
      outsidePolicy: outsidePolicy,
      outsideMessage: outsideMessage,
    );
  }

  /// Detect campus based on current location
  Future<String?> detectCurrentCampus({double tolerance = 50.0}) async {
    try {
      final position = await getCurrentLocation();
      return _campusService.findCampusForLocation(
        position.latitude,
        position.longitude,
        tolerance: tolerance,
      );
    } catch (e) {
      print('Error detecting campus: $e');
      return null;
    }
  }

  /// Get today's campus for a student based on their schedule
  String? getTodayCampusForStudent(StudentProfile studentProfile) {
    final campusId = studentProfile.getCampusForToday();
    final campus = _campusService.getCampusLocation(campusId);
    return campus?.name;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _locationSubscription;
  final CampusLocationService _campusService = CampusLocationService();

  /// Get available campus locations for UI selection
  List<Map<String, String>> getCampusOptions() {
    return _campusService.getCampusOptions();
  }

  /// Get today's geofence profile for current user or specified student - Never returns null
  Future<Map<String, dynamic>> getTodayGeofenceProfile([
    String? studentId,
  ]) async {
    try {
      final user = AuthService.instance.currentUser;
      final userId = studentId ?? user?.uid;
      if (userId == null) {
        print('⚠️ No user ID found, using Up Park Camp fallback');
        final now = DateTime.now();
        final dayName = _getDayName(now.weekday);
        return _createCampusProfile('up_park_camp', dayName);
      }

      final today = DateTime.now();
      final dateId =
          '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';

      print('🔍 Getting geofence profile for student: $userId, date: $dateId');

      final doc = await _firestore
          .collection('geofences')
          .doc(userId)
          .collection('days')
          .doc(dateId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        print('✅ Geofence profile found: $data');
        return data;
      } else {
        // No admin-set profile found, create one based on student's schedule
        print('📍 No admin profile found, creating from student schedule');
        final profile = await _createProfileFromStudentSchedule(userId, today);
        print('✅ Generated profile: $profile');
        return profile;
      }
    } catch (e) {
      print('❌ Error getting geofence profile: $e');
      // Always provide a fallback default profile
      final now = DateTime.now();
      final dayName = _getDayName(now.weekday);
      final defaultCampus = _getDefaultCampusForDay(now.weekday);
      print('🔧 Using emergency fallback profile: $defaultCampus for $dayName');
      return _createCampusProfile(defaultCampus, dayName);
    }
  }

  /// Create geofence profile from student's weekly schedule (handles both fixed and custom locations)
  Future<Map<String, dynamic>> _createProfileFromStudentSchedule(
    String studentId,
    DateTime today,
  ) async {
    try {
      // Get student's weekly schedule
      final scheduleDoc = await _firestore
          .collection('student_schedules')
          .doc(studentId)
          .get();

      final dayName = _getDayName(today.weekday);
      print('📅 Creating profile for $dayName');

      if (scheduleDoc.exists && scheduleDoc.data() != null) {
        final data = scheduleDoc.data()!;
        final weeklySchedule = data['weeklySchedule'] as Map<String, dynamic>?;

        if (weeklySchedule != null && weeklySchedule[dayName] != null) {
          final dayConfig = weeklySchedule[dayName];

          // Handle new format with type and custom locations
          if (dayConfig is Map<String, dynamic> &&
              dayConfig['type'] == 'custom') {
            print('📍 Using custom location for $dayName');

            // Check if custom location is set in the schedule
            Map<String, dynamic>? customLocationData;

            if (dayConfig['customLocation'] != null &&
                dayConfig['customLocation'] is Map<String, dynamic>) {
              customLocationData =
                  dayConfig['customLocation'] as Map<String, dynamic>;
            } else {
              // Fallback to the new geofence service
              try {
                customLocationData = await getGeofence(
                  AuthService.instance.currentUser?.uid ?? '',
                  dayName.toLowerCase(),
                );
              } catch (e) {
                print('Error loading geofence for $dayName: $e');
              }
            }

            if (customLocationData != null) {
              final lat = _extractDouble(customLocationData['lat']);
              final lng = _extractDouble(customLocationData['lng']);
              final radius =
                  _extractDouble(customLocationData['radius']) ?? 100.0;

              if (lat != null && lng != null) {
                print('✅ Custom location found: lat=$lat, lng=$lng, radius=${radius}m');
                print('📍 Creating custom geofence profile for $dayName');

                final profile = {
                  'checkInLocation': {'lat': lat, 'lng': lng, 'radius': radius},
                  'checkOutLocation': {
                    'lat': lat,
                    'lng': lng,
                    'radius': radius,
                  },
                  'bandType': 'fixed',
                  'outsidePolicy': 'allow_flag',
                  'outsideMessage':
                      'You are outside your custom location for $dayName (${radius.toInt()}m radius).',
                  'isCustomLocation': true,
                  'campusId': 'custom_location',
                  'campusName': 'Custom Location',
                };
                print('🎯 Returning custom profile: $profile');
                return profile;
              } else {
                print('❌ Invalid custom location coordinates: lat=$lat, lng=$lng');
              }
            } else {
              print('❌ No custom location data found');
            }

            // No custom location found - use campus fallback
            final campusId =
                dayConfig['campusId'] as String? ??
                _getDefaultCampusForDay(today.weekday);
            print('⚠️ Custom day but no location set, using campus: $campusId');
            return _createCampusProfile(campusId, dayName);
          } else {
            // Handle old format or fixed location
            String campusId;
            if (dayConfig is String) {
              campusId = dayConfig;
            } else if (dayConfig is Map<String, dynamic>) {
              campusId =
                  dayConfig['campusId'] as String? ??
                  _getDefaultCampusForDay(today.weekday);
            } else {
              campusId = _getDefaultCampusForDay(today.weekday);
            }

            print('📍 Using campus location: $campusId');
            return _createCampusProfile(campusId, dayName);
          }
        }
      }

      // Fallback to default schedule
      final defaultCampus = _getDefaultCampusForDay(today.weekday);
      print('📅 Using default campus for $dayName: $defaultCampus');
      return _createCampusProfile(defaultCampus, dayName);
    } catch (e) {
      print('❌ Error creating profile from student schedule: $e');
      final defaultCampus = _getDefaultCampusForDay(today.weekday);
      final dayName = _getDayName(today.weekday);
      return _createCampusProfile(defaultCampus, dayName);
    }
  }

  /// Create a campus-based geofence profile
  Map<String, dynamic> _createCampusProfile(String campusId, String dayName) {
    try {
      print('🏫 Creating campus profile for: $campusId');
      final profile = createProfileFromCampus(
        campusId,
        bandType: 'fixed',
        outsidePolicy: 'allow_flag',
        outsideMessage:
            'You are outside the ${campusId.replaceAll('_', ' ')} campus area.',
      );
      profile['isCustomLocation'] = false;
      print('✅ Campus profile created successfully: $profile');
      return profile;
    } catch (e) {
      print('❌ Error creating campus profile for $campusId: $e');
      // Return hardcoded fallback profile for Up Park Camp
      return {
        'checkInLocation': {'lat': 18.0123, 'lng': -76.7890, 'radius': 100.0},
        'checkOutLocation': {'lat': 18.0123, 'lng': -76.7890, 'radius': 100.0},
        'bandType': 'fixed',
        'outsidePolicy': 'allow_flag',
        'outsideMessage': 'You are outside the Up Park Camp area.',
        'campusId': 'up_park_camp',
        'campusName': 'Up Park Camp',
        'isCustomLocation': false,
      };
    }
  }

  /// Get day name from weekday number
  String _getDayName(int weekday) {
    const days = [
      '', // 0 is not used
      'monday', // 1
      'tuesday', // 2
      'wednesday', // 3
      'thursday', // 4
      'friday', // 5
      'saturday', // 6
      'sunday', // 7
    ];
    return days[weekday];
  }

  /// Get default campus based on day of week - Always defaults to Up Park Camp as fallback
  String _getDefaultCampusForDay(int weekday) {
    // Always use Up Park Camp as default fallback instead of day-specific logic
    print('🏫 Using Up Park Camp as default campus for any day');
    return 'up_park_camp';
  }

  /// Calculate distance between two points using Haversine formula
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Check if user is within geofence
  bool isWithinGeofence(
    Position userLocation,
    Map<String, dynamic> geofenceLocation,
  ) {
    final distance = calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      geofenceLocation['lat'],
      geofenceLocation['lng'],
    );
    return distance <= geofenceLocation['radius'];
  }

  /// Get current location with proper permissions handling
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw GeofenceException(
        'Location services are disabled. Please enable location services.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw GeofenceException('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw GeofenceException(
        'Location permissions are permanently denied. Please enable them in settings.',
      );
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
  }

  /// Comprehensive location validation for check-in/out
  Future<GeofenceValidationResult> validateLocation(
    String action, [
    dynamic profileOverride,
  ]) async {
    try {
      print('🔍 Starting location validation for action: $action');

      final position = await getCurrentLocation();
      print('📍 Current position: ${position.latitude}, ${position.longitude}');

      // Use provided profile override or get today's profile
      dynamic profile = profileOverride ?? await getTodayGeofenceProfile();

      if (profile == null) {
        return GeofenceValidationResult(
          isValid: false,
          message:
              'No geofence profile found for today. Contact your administrator.',
          distance: 0,
          errorType: GeofenceErrorType.noProfile,
        );
      }

      // Handle both GeofenceProfile objects and legacy Map format
      double? targetLat, targetLng, radius;
      String outsidePolicy = 'allow';
      String bandType = 'fixed';

      if (profile is GeofenceProfile) {
        // New GeofenceProfile format
        if (action == 'checkin') {
          targetLat = profile.inLat;
          targetLng = profile.inLng;
          radius = profile.inRadius;
        } else {
          targetLat = profile.outLat;
          targetLng = profile.outLng;
          radius = profile.outRadius;
        }
        outsidePolicy = profile.outsidePolicy;
        bandType = profile.bandType;
      } else if (profile is Map<String, dynamic>) {
        // Legacy Map format
        final String locationKey = action == 'checkin'
            ? 'checkInLocation'
            : 'checkOutLocation';
        final targetLocation = profile[locationKey] as Map<String, dynamic>?;

        if (targetLocation == null) {
          return GeofenceValidationResult(
            isValid: false,
            message: 'No $action location configured for today.',
            distance: 0,
            errorType: GeofenceErrorType.noTargetLocation,
          );
        }

        targetLat = targetLocation['lat'] as double?;
        targetLng = targetLocation['lng'] as double?;
        radius = targetLocation['radius'] as double?;
        outsidePolicy = profile['outsidePolicy'] ?? 'allow';
        bandType = profile['bandType'] ?? 'fixed';
      }

      if (targetLat == null || targetLng == null || radius == null) {
        return GeofenceValidationResult(
          isValid: false,
          message: 'Invalid geofence configuration for $action.',
          distance: 0,
          errorType: GeofenceErrorType.noTargetLocation,
        );
      }

      final distance = calculateDistance(
        position.latitude,
        position.longitude,
        targetLat,
        targetLng,
      );

      final isWithin = distance <= radius;

      // Create location map for incident logging
      final targetLocation = {
        'lat': targetLat,
        'lng': targetLng,
        'radius': radius,
      };

      print(
        '📏 Distance to target: ${distance.toInt()}m, Required radius: ${targetLocation['radius']}m',
      );
      print('🔒 Outside policy: $outsidePolicy, Band type: $bandType');

      // Handle floating band type - always allow regardless of location
      if (bandType == 'floating') {
        print('🌊 Floating geofence - action always allowed');
        return GeofenceValidationResult(
          isValid: true,
          message: 'Floating geofence - $action allowed from any location',
          distance: distance,
          position: position,
        );
      }

      // Handle different scenarios
      if (isWithin) {
        print('✅ User is within geofence');
        return GeofenceValidationResult(
          isValid: true,
          message: 'Location verified successfully',
          distance: distance,
          position: position,
        );
      }

      // User is outside geofence - handle based on policy
      if (outsidePolicy == 'block') {
        print('🚫 User blocked due to outside policy');
        await _createGeofenceIncident(
          action,
          position,
          targetLocation,
          distance,
          profile,
        );
        return GeofenceValidationResult(
          isValid: false,
          message:
              'You are ${distance.toInt()}m away from the required location. Move closer to ${action}.',
          distance: distance,
          errorType: GeofenceErrorType.outsideGeofence,
          position: position,
        );
      }

      if (outsidePolicy == 'allow' || outsidePolicy == 'allow_flag') {
        print('⚠️ User allowed but flagged');
        await _createGeofenceIncident(
          action,
          position,
          targetLocation,
          distance,
          profile,
        );

        // Use custom message if available
        String? customMessage;
        if (profile is GeofenceProfile) {
          customMessage = profile.outsideMessage;
        } else if (profile is Map<String, dynamic>) {
          customMessage = profile['outsideMessage'] as String?;
        }
        final message =
            customMessage ??
            '$action allowed but flagged (${distance.toInt()}m away from required location)';

        return GeofenceValidationResult(
          isValid: true,
          message: message,
          distance: distance,
          flagged: true,
          position: position,
        );
      }

      return GeofenceValidationResult(
        isValid: false,
        message: 'Unknown geofence policy. Contact administrator.',
        distance: distance,
        errorType: GeofenceErrorType.unknown,
      );
    } catch (e) {
      print('❌ Location validation error: $e');
      return GeofenceValidationResult(
        isValid: false,
        message: 'Location validation failed: ${e.toString()}',
        distance: 0,
        errorType: GeofenceErrorType.systemError,
      );
    }
  }

  /// Create detailed geofence incidents for tracking and admin alerts
  Future<void> _createGeofenceIncident(
    String action,
    Position userLocation,
    Map<String, dynamic> targetLocation,
    double distance,
    Map<String, dynamic> geofenceProfile,
  ) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      // Get user details for better incident tracking
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final studentName = userData?['name'] ?? 'Unknown Student';
      final studentEmail = userData?['email'] ?? user.email ?? 'No email';

      final today = DateTime.now();
      final dateId =
          '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
      final dayName = _getDayName(today.weekday);

      // Determine location type
      final isCustomLocation = geofenceProfile['isCustomLocation'] == true;
      final locationType = isCustomLocation ? 'custom' : 'campus';

      final incidentData = {
        'studentId': user.uid,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'action': action,
        'dateId': dateId,
        'dayName': dayName,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': Timestamp.now(),
        'userLocation': {
          'lat': userLocation.latitude,
          'lng': userLocation.longitude,
          'accuracy': userLocation.accuracy,
        },
        'targetLocation': targetLocation,
        'distance': distance,
        'locationType': locationType,
        'geofenceProfile': {
          'bandType': geofenceProfile['bandType'],
          'outsidePolicy': geofenceProfile['outsidePolicy'],
          'isCustomLocation': isCustomLocation,
        },
        'message': _generateIncidentMessage(
          studentName,
          action,
          distance,
          locationType,
          dayName,
        ),
        'resolved': false,
        'severity': distance > 500
            ? 'high'
            : distance > 200
            ? 'medium'
            : 'low',
        'requiresAdminReview': isCustomLocation,
        'adminNotified': false,
      };

      // Create the incident
      final incidentRef = await _firestore
          .collection('geofence_incidents')
          .add(incidentData);
      print('📝 Geofence incident created: ${incidentRef.id}');

      // Create admin notification for custom location violations
      if (isCustomLocation) {
        await _createAdminNotification(incidentRef.id, incidentData);
      }
    } catch (e) {
      print('❌ Error creating geofence incident: $e');
    }
  }

  /// Generate descriptive incident message
  String _generateIncidentMessage(
    String studentName,
    String action,
    double distance,
    String locationType,
    String dayName,
  ) {
    final locationDesc = locationType == 'custom'
        ? 'custom location'
        : 'designated campus area';

    return '$studentName attempted to $action on $dayName but was ${distance.toInt()}m away from their $locationDesc.';
  }

  /// Create admin notification for geofence violations
  Future<void> _createAdminNotification(
    String incidentId,
    Map<String, dynamic> incidentData,
  ) async {
    try {
      final notificationData = {
        'type': 'geofence_violation',
        'incidentId': incidentId,
        'studentId': incidentData['studentId'],
        'studentName': incidentData['studentName'],
        'action': incidentData['action'],
        'dayName': incidentData['dayName'],
        'distance': incidentData['distance'],
        'locationType': incidentData['locationType'],
        'severity': incidentData['severity'],
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': Timestamp.now(),
        'read': false,
        'priority': incidentData['severity'] == 'high' ? 'urgent' : 'normal',
        'title': '🚨 Geofence Violation - ${incidentData['studentName']}',
        'message': incidentData['message'],
      };

      await _firestore.collection('admin_notifications').add(notificationData);

      // Mark incident as admin notified
      await _firestore.collection('geofence_incidents').doc(incidentId).update({
        'adminNotified': true,
      });

      print('📢 Admin notification created for incident: $incidentId');
    } catch (e) {
      print('❌ Error creating admin notification: $e');
    }
  }

  /// Get student's geofence incidents stream
  Stream<QuerySnapshot> getStudentIncidents([String? studentId]) {
    final user = AuthService.instance.currentUser;
    final userId = studentId ?? user?.uid;

    if (userId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('geofence_incidents')
        .where('studentId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get incidents with date filtering (simplified to avoid composite index requirement)
  Stream<QuerySnapshot> getStudentIncidentsWithDateFilter(
    DateTime startDate,
    DateTime endDate, [
    String? studentId,
  ]) {
    final user = AuthService.instance.currentUser;
    final userId = studentId ?? user?.uid;

    if (userId == null) {
      return const Stream.empty();
    }

    // Simplified query to avoid composite index requirement
    // The date filtering will be done client-side in the UI
    return _firestore
        .collection('geofence_incidents')
        .where('studentId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100) // Limit to reduce data transfer
        .snapshots();
  }

  /// Get distance status for UI updates
  Future<Map<String, dynamic>> getLocationStatus() async {
    try {
      final position = await getCurrentLocation();
      final profile = await getTodayGeofenceProfile();

      final checkInLocation =
          profile['checkInLocation'] as Map<String, dynamic>?;
      final checkOutLocation =
          profile['checkOutLocation'] as Map<String, dynamic>?;
      final outsidePolicy = profile['outsidePolicy'] ?? 'block';

      double checkInDistance = 0;
      double checkOutDistance = 0;
      bool canCheckIn = false;
      bool canCheckOut = false;

      if (checkInLocation != null) {
        checkInDistance = calculateDistance(
          position.latitude,
          position.longitude,
          checkInLocation['lat'],
          checkInLocation['lng'],
        );
        canCheckIn =
            checkInDistance <= checkInLocation['radius'] ||
            outsidePolicy == 'allow';
      }

      if (checkOutLocation != null) {
        checkOutDistance = calculateDistance(
          position.latitude,
          position.longitude,
          checkOutLocation['lat'],
          checkOutLocation['lng'],
        );
        canCheckOut =
            checkOutDistance <= checkOutLocation['radius'] ||
            outsidePolicy == 'allow';
      }

      return {
        'hasProfile': true,
        'position': position,
        'profile': profile,
        'checkInDistance': checkInDistance,
        'checkOutDistance': checkOutDistance,
        'canCheckIn': canCheckIn,
        'canCheckOut': canCheckOut,
        'outsidePolicy': outsidePolicy,
      };
    } catch (e) {
      return {
        'hasProfile': false,
        'error': e.toString(),
        'canCheckIn': false,
        'canCheckOut': false,
      };
    }
  }

  /// Start real-time location monitoring
  StreamSubscription<Position> startLocationMonitoring({
    required Function(Position) onLocationUpdate,
    required Function(String) onGeofenceViolation,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
        timeLimit: Duration(seconds: 30),
      ),
    ).listen((position) async {
      onLocationUpdate(position);

      // Check for geofence violations
      final profile = await getTodayGeofenceProfile();
      await _checkGeofenceViolations(position, profile, onGeofenceViolation);
    }, onError: (e) => print('Location monitoring error: $e'));
  }

  Future<void> _checkGeofenceViolations(
    Position position,
    Map<String, dynamic> profile,
    Function(String) onViolation,
  ) async {
    // Check both check-in and check-out locations
    final checkInLocation = profile['checkInLocation'] as Map<String, dynamic>?;
    final checkOutLocation =
        profile['checkOutLocation'] as Map<String, dynamic>?;

    if (checkInLocation != null) {
      final checkInDistance = calculateDistance(
        position.latitude,
        position.longitude,
        checkInLocation['lat'],
        checkInLocation['lng'],
      );

      // If user is far from check-in location, trigger violation
      if (checkInDistance > (checkInLocation['radius'] * 2)) {
        onViolation(
          'Student is ${checkInDistance.toInt()}m away from check-in location',
        );
      }
    }

    if (checkOutLocation != null) {
      final checkOutDistance = calculateDistance(
        position.latitude,
        position.longitude,
        checkOutLocation['lat'],
        checkOutLocation['lng'],
      );

      // If user is far from check-out location, trigger violation
      if (checkOutDistance > (checkOutLocation['radius'] * 2)) {
        onViolation(
          'Student is ${checkOutDistance.toInt()}m away from check-out location',
        );
      }
    }
  }

  /// Save or update a geofence profile for a specific day (from original GeofenceService)
  Future<void> setProfile({
    required String studentId,
    required String dateId, // e.g. 20251001
    required GeofenceProfile profile,
  }) async {
    await _firestore
        .collection('geofences')
        .doc(studentId)
        .collection('days')
        .doc(dateId)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  /// Fetch a geofence profile for a specific day, falling back to default if none exists
  Future<GeofenceProfile> getProfile({
    required String studentId,
    required String dateId,
  }) async {
    final doc = await _firestore
        .collection('geofences')
        .doc(studentId)
        .collection('days')
        .doc(dateId)
        .get();

    if (doc.exists) {
      return GeofenceProfile.fromDoc(doc);
    }

    // No profile saved → return default based on day of week
    final dt = DateTime.parse(dateId); // dateId like 20251001
    return _defaultProfileForDay(dt);
  }

  /// Log a geofence incident when a student clocks in/out outside the zone (from original service)
  Future<void> logIncident({
    required String studentId,
    required String dateId,
    required String type, // "checkin" or "checkout"
    required double actualLat,
    required double actualLng,
    required double designatedLat,
    required double designatedLng,
    required double distance,
  }) async {
    await _firestore
        .collection('geofenceIncidents')
        .doc(studentId)
        .collection('incidents')
        .add({
          'type': type,
          'dateId': dateId,
          'actualLat': actualLat,
          'actualLng': actualLng,
          'designatedLat': designatedLat,
          'designatedLng': designatedLng,
          'distance': distance,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// Stream incidents for a student (from original service)
  Stream<QuerySnapshot<Map<String, dynamic>>> getIncidents(String studentId) {
    return _firestore
        .collection('geofenceIncidents')
        .doc(studentId)
        .collection('incidents')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Internal helper to return the default profile based on day of week
  GeofenceProfile _defaultProfileForDay(DateTime day) {
    final stonyHill = {'lat': 18.05, 'lng': -76.82, 'radius': 150.0};
    final upPark = {'lat': 18.00, 'lng': -76.80, 'radius': 150.0};

    final def =
        (day.weekday == DateTime.wednesday || day.weekday == DateTime.thursday)
        ? stonyHill
        : upPark;

    return GeofenceProfile(
      inLat: def['lat']!,
      inLng: def['lng']!,
      inRadius: def['radius']!,
      outLat: def['lat']!,
      outLng: def['lng']!,
      outRadius: def['radius']!,
      bandType: 'fixed', // default band type
      outsidePolicy: 'allow_flag', // default policy - allow but log incidents
      outsideMessage:
          'You are outside the designated campus area.', // informative message
    );
  }

  /// Get all geofence profiles for a student (admin use)
  Future<List<Map<String, dynamic>>> getAllStudentProfiles(
    String studentId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('geofences')
          .doc(studentId)
          .collection('days')
          .get();

      return snapshot.docs
          .map((doc) => {'dateId': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error getting student profiles: $e');
      return [];
    }
  }

  /// Save geofence for a specific weekday (Mon–Fri only)
  Future<void> saveGeofence(
    String userId,
    String day,
    double lat,
    double lng,
    double radius,
  ) async {
    // ensure day is lowercase and valid
    final validDays = ["monday", "tuesday", "wednesday", "thursday", "friday"];
    if (!validDays.contains(day.toLowerCase())) {
      throw Exception("Invalid day. Use Monday–Friday only.");
    }

    await _firestore.collection("users").doc(userId).set({
      "geofences": {
        day.toLowerCase(): {"lat": lat, "lng": lng, "radius": radius},
      },
    }, SetOptions(merge: true));
  }

  /// Get one day's geofence
  Future<Map<String, dynamic>?> getGeofence(String userId, String day) async {
    final snapshot = await _firestore.collection("users").doc(userId).get();
    if (!snapshot.exists) return null;

    final data = snapshot.data();
    if (data == null || data["geofences"] == null) return null;

    final geofences = data["geofences"] as Map<String, dynamic>;
    return geofences[day.toLowerCase()] as Map<String, dynamic>?;
  }

  /// Get all geofences (Mon–Fri)
  Future<Map<String, Map<String, dynamic>>> getAllGeofences(
    String userId,
  ) async {
    final snapshot = await _firestore.collection("users").doc(userId).get();
    final Map<String, Map<String, dynamic>> result = {};

    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      if (data["geofences"] != null) {
        final geofences = data["geofences"] as Map<String, dynamic>;
        for (final day in [
          "monday",
          "tuesday",
          "wednesday",
          "thursday",
          "friday",
        ]) {
          if (geofences[day] != null) {
            result[day] = Map<String, dynamic>.from(geofences[day]);
          }
        }
      }
    }
    return result;
  }

  /// Helper method to safely extract double values
  double? _extractDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return null;
  }

  /// Validates if the given day is a valid weekday (Monday-Friday)
  static bool isValidDay(String day) {
    const validDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
    return validDays.contains(day.toLowerCase());
  }

  void dispose() {
    _locationSubscription?.cancel();
  }
}

/// Geofence validation result with detailed information
class GeofenceValidationResult {
  final bool isValid;
  final String message;
  final double distance;
  final bool flagged;
  final Position? position;
  final GeofenceErrorType? errorType;

  GeofenceValidationResult({
    required this.isValid,
    required this.message,
    required this.distance,
    this.flagged = false,
    this.position,
    this.errorType,
  });
}

/// Types of geofence validation errors
enum GeofenceErrorType {
  noProfile,
  noTargetLocation,
  outsideGeofence,
  systemError,
  unknown,
}

/// Custom exception for geofence-related errors
class GeofenceException implements Exception {
  final String message;
  GeofenceException(this.message);

  @override
  String toString() => 'GeofenceException: $message';
}
