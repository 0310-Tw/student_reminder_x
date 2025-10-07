import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:students_reminder/src/features/geofence/geofence_service.dart';

import '../../services/auth_service.dart';
import 'widgets/location_picker_map.dart';

class StudentLocationSelectionPage extends StatefulWidget {
  const StudentLocationSelectionPage({Key? key}) : super(key: key);

  @override
  State<StudentLocationSelectionPage> createState() =>
      _StudentLocationSelectionPageState();
}

class _StudentLocationSelectionPageState
    extends State<StudentLocationSelectionPage> {
  final GeofenceService _geofenceService = GeofenceService();

  Map<String, dynamic> _weeklySchedule = {
    'monday': {
      'type': 'custom',
      'campusId': 'up_park_camp', // Fallback for display
    },
    'tuesday': {
      'type': 'custom',
      'campusId': 'up_park_camp', // Fallback for display
    },
    'wednesday': {
      'type': 'fixed',
      'campusId': 'stony_hill', // Default to Stony Hill
    },
    'thursday': {
      'type': 'fixed',
      'campusId': 'stony_hill', // Default to Stony Hill
    },
    'friday': {
      'type': 'custom',
      'campusId': 'up_park_camp', // Fallback for display
    },
    'saturday': {'type': 'fixed', 'campusId': 'up_park_camp'},
    'sunday': {'type': 'fixed', 'campusId': 'up_park_camp'},
  };

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentSchedule();
  }

  // Helper method to safely extract campus ID as string
  String _getCampusIdAsString(dynamic campusIdValue) {
    if (campusIdValue is String) {
      return campusIdValue;
    } else if (campusIdValue is Map && campusIdValue.containsKey('id')) {
      return campusIdValue['id'].toString();
    } else {
      // Return fallback value
      return 'up_park_camp';
    }
  }

  // Helper method to safely extract numeric values from custom location
  double _safeToDouble(dynamic value, double fallback) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  int _safeToInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  // Debug method to validate schedule data structure
  void _validateScheduleData() {
    _weeklySchedule.forEach((day, config) {
      if (config is! Map<String, dynamic>) {
        print(
          'Warning: $day config is not a Map: $config (${config.runtimeType})',
        );
      } else {
        if (!config.containsKey('type') || !config.containsKey('campusId')) {
          print('Warning: $day missing required fields: $config');
        }
        if (config['campusId'] is! String) {
          print(
            'Warning: $day campusId is not String: ${config['campusId']} (${config['campusId'].runtimeType})',
          );
          // Fix the campusId on the spot
          config['campusId'] = _getCampusIdAsString(config['campusId']);
        }
      }
    });
  }

  Future<void> _loadCurrentSchedule() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'User not authenticated';
            _isLoading = false;
          });
        }
        return;
      }

      // Load both weekly schedule and geofences
      final doc = await FirebaseFirestore.instance
          .collection('student_schedules')
          .doc(user.uid)
          .get();

      // Load geofences for custom locations
      await _loadGeofences();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['weeklySchedule'] != null) {
          if (mounted) {
            setState(() {
              final savedSchedule =
                  data['weeklySchedule'] as Map<String, dynamic>;
              // Migrate old format to new format if needed
              _weeklySchedule = savedSchedule.map((day, value) {
                if (value is String) {
                  // Old format - convert to new format
                  final isFlexibleDay = [
                    'monday',
                    'tuesday',
                    'friday',
                  ].contains(day);
                  return MapEntry(day, {
                    'type': isFlexibleDay ? 'custom' : 'fixed',
                    'campusId': value,
                  });
                } else if (value is Map<String, dynamic>) {
                  // New format - ensure it has required fields
                  final Map<String, dynamic> dayConfig = Map.from(value);

                  // Ensure type field exists
                  if (!dayConfig.containsKey('type')) {
                    final isFlexibleDay = [
                      'monday',
                      'tuesday',
                      'friday',
                    ].contains(day);
                    dayConfig['type'] = isFlexibleDay ? 'custom' : 'fixed';
                  }

                  // Ensure campusId field exists and is a String
                  if (!dayConfig.containsKey('campusId')) {
                    dayConfig['campusId'] =
                        day == 'wednesday' || day == 'thursday'
                        ? 'stony_hill'
                        : 'up_park_camp';
                  } else {
                    // Convert campusId to String if it's not already
                    final campusIdValue = dayConfig['campusId'];
                    if (campusIdValue is! String) {
                      if (campusIdValue is Map &&
                          campusIdValue.containsKey('id')) {
                        dayConfig['campusId'] = campusIdValue['id'].toString();
                      } else {
                        dayConfig['campusId'] =
                            day == 'wednesday' || day == 'thursday'
                            ? 'stony_hill'
                            : 'up_park_camp';
                      }
                    }
                  }

                  return MapEntry(day, dayConfig);
                } else {
                  // Fallback for unexpected format
                  final isFlexibleDay = [
                    'monday',
                    'tuesday',
                    'friday',
                  ].contains(day);
                  return MapEntry(day, {
                    'type': isFlexibleDay ? 'custom' : 'fixed',
                    'campusId': day == 'wednesday' || day == 'thursday'
                        ? 'stony_hill'
                        : 'up_park_camp',
                  });
                }
              });
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Validate loaded data in debug mode
        _validateScheduleData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load schedule: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Method to clean and normalize the schedule data before saving
  Map<String, dynamic> _cleanScheduleData() {
    final cleaned = <String, dynamic>{};

    _weeklySchedule.forEach((day, config) {
      if (config is Map<String, dynamic>) {
        final cleanedConfig = Map<String, dynamic>.from(config);

        // Ensure campusId is always a string
        cleanedConfig['campusId'] = _getCampusIdAsString(
          cleanedConfig['campusId'],
        );

        // Ensure type field is present
        if (!cleanedConfig.containsKey('type')) {
          final isFlexibleDay = ['monday', 'tuesday', 'friday'].contains(day);
          cleanedConfig['type'] = isFlexibleDay ? 'custom' : 'fixed';
        }

        cleaned[day] = cleanedConfig;
      }
    });

    return cleaned;
  }

  Future<void> _saveSchedule() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      if (mounted) {
        setState(() => _isSaving = true);
      }

      // Save weekly schedule with cleaned data
      final cleanedSchedule = _cleanScheduleData();
      await FirebaseFirestore.instance
          .collection('student_schedules')
          .doc(user.uid)
          .set({
            'weeklySchedule': cleanedSchedule,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': 'student',
          }, SetOptions(merge: true));

      // Save geofences using the new service
      await _saveGeofences();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weekly schedule saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Load geofences from the new geofence service
  Future<void> _loadGeofences() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      // Load from geofence_profiles subcollection (same as admin)
      final geofenceProfilesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('geofence_profiles')
          .get();

      if (mounted) {
        setState(() {
          // Update weekly schedule with loaded geofence profiles
          for (final doc in geofenceProfilesSnapshot.docs) {
            final day = doc.id;
            final geofenceData = doc.data();

            if (_weeklySchedule.containsKey(day)) {
              final dayConfig = _weeklySchedule[day] as Map<String, dynamic>;
              final source = geofenceData['source']?.toString();

              // Show the location regardless of source (admin override or student custom)
              if (geofenceData['latitude'] != null &&
                  geofenceData['longitude'] != null) {
                // If admin has set a location, mark it as non-editable so student can see but can't edit
                if (source == 'adminOverride') {
                  dayConfig['type'] =
                      'admin_override'; // Admin override - make it read-only
                  dayConfig['campusId'] = 'admin_override';
                  dayConfig['isReadOnly'] =
                      true; // Flag to indicate admin control
                } else if (source == 'studentCustom') {
                  dayConfig['type'] =
                      'custom'; // Student can still edit their own
                  dayConfig['isReadOnly'] = false;
                }

                dayConfig['customLocation'] = {
                  'lat': _safeToDouble(geofenceData['latitude'], 0.0),
                  'lng': _safeToDouble(geofenceData['longitude'], 0.0),
                  'radius': _safeToDouble(geofenceData['radius'], 100.0),
                  'description':
                      geofenceData['description'] ?? 'Location for $day',
                  'source': source, // Include source info for UI display
                  if (geofenceData['address'] != null)
                    'address': geofenceData['address'].toString(),
                };
              }
            }
          }
        });
      }
    } catch (e) {
      print('Error loading geofences: $e');
      // Don't show error to user, just continue with existing schedule
    }
  }

  /// Save geofences to the new geofence service
  Future<void> _saveGeofences() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      // Save custom locations to geofence_profiles subcollection (same as admin)
      for (final entry in _weeklySchedule.entries) {
        final day = entry.key;
        final dayConfig = entry.value as Map<String, dynamic>;

        // Check if this day is admin-controlled and should not be modified by student
        final isAdminControlled =
            dayConfig['isReadOnly'] == true ||
            dayConfig['type'] == 'admin_override';

        // Only save geofences for custom days and Monday-Friday, and NOT admin overrides
        if (dayConfig['type'] == 'custom' &&
            GeofenceService.isValidDay(day) &&
            dayConfig['customLocation'] != null &&
            !isAdminControlled) {
          final customLoc = dayConfig['customLocation'] as Map<String, dynamic>;
          final lat = _extractDouble(customLoc['lat']);
          final lng = _extractDouble(customLoc['lng']);
          final radius = _extractDouble(customLoc['radius']);

          if (lat != null && lng != null && radius != null) {
            // Save to the same collection that admin uses
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('geofence_profiles')
                .doc(day.toLowerCase())
                .set({
                  'latitude': lat,
                  'longitude': lng,
                  'radius': radius,
                  'source': 'studentCustom',
                  'description':
                      customLoc['description'] ?? 'Custom location for $day',
                  'bandType':
                      'fixed', // Student custom locations are typically fixed
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': 'student',
                }, SetOptions(merge: true));
          }
        } else if (isAdminControlled) {
          // Log when we skip saving due to admin override
          print('Skipping save for $day - Admin override active');
        }
      }
    } catch (e) {
      print('Error saving geofences: $e');
      // Continue with the save process even if geofence saving fails
    }
  }

  /// Helper method to safely extract double values
  double? _extractDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return null;
  }

  void _updateDayLocation(String day, String campusId) {
    if (mounted) {
      setState(() {
        if (_weeklySchedule.containsKey(day) &&
            _weeklySchedule[day] is Map<String, dynamic>) {
          final dayConfig = _weeklySchedule[day] as Map<String, dynamic>;

          // Check if this day is admin-controlled and should not be modified by student
          final isAdminControlled =
              dayConfig['isReadOnly'] == true ||
              dayConfig['type'] == 'admin_override';

          if (isAdminControlled) {
            // Show error message and return early
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'This location was set by an administrator and cannot be changed',
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          dayConfig['campusId'] = campusId;
          // Clear any existing custom location if switching to a different campus
          if (dayConfig.containsKey('customLocation')) {
            dayConfig.remove('customLocation');
          }
        }
      });
    }
  }

  Future<void> _openLocationPicker(String day) async {
    final dayConfig = _weeklySchedule[day] as Map<String, dynamic>;

    // Check if this day is admin-controlled and should not be modified by student
    final isAdminControlled =
        dayConfig['isReadOnly'] == true ||
        dayConfig['type'] == 'admin_override';

    if (isAdminControlled) {
      // Show error message and return early
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This location was set by an administrator and cannot be changed',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    LatLng? initialLocation;
    double initialRadius = 100.0;

    // Get existing custom location if available
    if (dayConfig['customLocation'] != null) {
      final customLoc = dayConfig['customLocation'] as Map<String, dynamic>;
      final lat = _safeToDouble(customLoc['lat'], 18.0179);
      final lng = _safeToDouble(customLoc['lng'], -76.8099);
      initialLocation = LatLng(lat, lng);
      initialRadius = _safeToDouble(customLoc['radius'], 100.0);
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMap(
          initialLocation: initialLocation,
          initialRadius: initialRadius,
          dayName: day[0].toUpperCase() + day.substring(1),
        ),
      ),
    );

    if (result != null) {
      final lat = result['lat'] as double;
      final lng = result['lng'] as double;
      final radius = result['radius'] as double;

      // Try to get address for the location
      String? address;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          address = [
            placemark.street,
            placemark.locality,
            placemark.administrativeArea,
          ].where((part) => part?.isNotEmpty == true).join(', ');
        }
      } catch (e) {
        print('Error getting address: $e');
      }

      if (mounted) {
        setState(() {
          dayConfig['customLocation'] = {
            'lat': lat,
            'lng': lng,
            'radius': radius,
            if (address?.isNotEmpty == true) 'address': address,
          };
        });
      }
    }
  }

  void _resetToDefaults() {
    if (mounted) {
      setState(() {
        _weeklySchedule = {
          'monday': {'type': 'custom', 'campusId': 'up_park_camp'},
          'tuesday': {'type': 'custom', 'campusId': 'up_park_camp'},
          'wednesday': {'type': 'fixed', 'campusId': 'stony_hill'},
          'thursday': {'type': 'fixed', 'campusId': 'stony_hill'},
          'friday': {'type': 'custom', 'campusId': 'up_park_camp'},
          'saturday': {'type': 'fixed', 'campusId': 'up_park_camp'},
          'sunday': {'type': 'fixed', 'campusId': 'up_park_camp'},
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.indigo.shade50],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Loading your schedule...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.shade50, Colors.pink.shade50],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Oops! Something went wrong',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _loadCurrentSchedule,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final campusOptions = _geofenceService.getCampusOptions();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.indigo.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Weekly Location Schedule',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _resetToDefaults,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
              label: const Text(
                'Reset',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced info header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.indigo.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...[
                  'monday',
                  'tuesday',
                  'wednesday',
                  'thursday',
                  'friday',
                ].map((day) => _buildDayScheduleCard(day, campusOptions)),
                const SizedBox(height: 16),

                const SizedBox(height: 16),
                _buildSaveButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayScheduleCard(
    String day,
    List<Map<String, String>> campusOptions,
  ) {
    final dayName = day[0].toUpperCase() + day.substring(1);
    final dayConfig = _weeklySchedule[day] as Map<String, dynamic>;
    final isCustomDay = dayConfig['type'] == 'custom';
    final isAdminOverride = dayConfig['type'] == 'admin_override';
    final isReadOnly = dayConfig['isReadOnly'] == true;
    final isDefaultDay = day == 'wednesday' || day == 'thursday';

    String displayName;
    String? addressText;
    bool hasCustomLocation = false;
    String? locationSource;

    if ((isCustomDay || isAdminOverride) &&
        dayConfig['customLocation'] != null) {
      final customLoc = dayConfig['customLocation'] as Map<String, dynamic>;
      final lat = _safeToDouble(customLoc['lat'], 0.0).toStringAsFixed(4);
      final lng = _safeToDouble(customLoc['lng'], 0.0).toStringAsFixed(4);
      final radius = _safeToInt(customLoc['radius'], 100);
      locationSource = customLoc['source']?.toString();

      if (isAdminOverride || locationSource == 'adminOverride') {
        displayName = '🔒 ADMIN OVERRIDE';
      } else {
        displayName = 'Custom Location Set';
      }

      // Use address if available, otherwise show coordinates
      if (customLoc['address'] != null &&
          customLoc['address'].toString().isNotEmpty) {
        if (isAdminOverride || locationSource == 'adminOverride') {
          addressText =
              '🚨 Admin Set: ${customLoc['address']} (${radius}m radius)';
        } else {
          addressText = '📍 ${customLoc['address']} (${radius}m radius)';
        }
      } else {
        if (isAdminOverride || locationSource == 'adminOverride') {
          addressText =
              '🚨 Admin Set: Lat: $lat, Lng: $lng (${radius}m radius)';
        } else {
          addressText = '📍 Lat: $lat, Lng: $lng (${radius}m radius)';
        }
      }
      hasCustomLocation = true;
    } else {
      // Safe type handling for campusId
      final selectedCampusId = _getCampusIdAsString(dayConfig['campusId']);

      final matchedCampus = campusOptions.firstWhere(
        (campus) => campus['id'] == selectedCampusId,
        orElse: () => <String, String>{
          'name': 'Unknown Campus',
          'id': 'unknown',
        },
      );
      displayName = matchedCampus['name'] ?? 'Unknown Campus';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isAdminOverride
              ? [
                  Colors.red.shade50,
                  Colors.red.shade100,
                ] // Red for admin overrides
              : isCustomDay
              ? [Colors.green.shade50, Colors.green.shade100]
              : isDefaultDay
              ? [Colors.orange.shade50, Colors.orange.shade100]
              : [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isAdminOverride
                        ? Colors.red
                        : isCustomDay
                        ? Colors.green
                        : isDefaultDay
                        ? Colors.orange
                        : Colors.blue)
                    .withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                (isAdminOverride
                        ? Colors.red
                        : isCustomDay
                        ? Colors.green
                        : isDefaultDay
                        ? Colors.orange
                        : Colors.blue)
                    .withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header with enhanced styling
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAdminOverride
                          ? [Colors.red.shade400, Colors.red.shade600]
                          : isCustomDay
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : isDefaultDay
                          ? [Colors.orange.shade400, Colors.orange.shade600]
                          : [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isAdminOverride
                                ? Colors.red
                                : isCustomDay
                                ? Colors.green
                                : isDefaultDay
                                ? Colors.orange
                                : Colors.blue)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAdminOverride
                            ? Icons.admin_panel_settings
                            : isCustomDay
                            ? Icons.my_location
                            : isDefaultDay
                            ? Icons.location_on
                            : Icons.school,
                        size: 14,
                        color: isAdminOverride
                            ? Colors.red.shade600
                            : isCustomDay
                            ? Colors.green.shade600
                            : isDefaultDay
                            ? Colors.orange.shade600
                            : Colors.blue.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAdminOverride
                            ? 'ADMIN OVERRIDE'
                            : isCustomDay
                            ? 'Flexible'
                            : isDefaultDay
                            ? 'Fixed'
                            : 'Campus',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isAdminOverride
                              ? Colors.red.shade600
                              : isCustomDay
                              ? Colors.green.shade600
                              : isDefaultDay
                              ? Colors.orange.shade600
                              : Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (hasCustomLocation)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.green.shade600,
                    ),
                  ),
              ],
            ),

            // Admin Override Warning Banner
            if (isAdminOverride || isReadOnly) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This location was set by an administrator and cannot be changed',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            if (isCustomDay || isAdminOverride) ...[
              // Enhanced custom location section
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: InkWell(
                  onTap: isReadOnly
                      ? null
                      : () => _openLocationPicker(
                          day,
                        ), // Disable tap for admin overrides
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isReadOnly
                            ? [
                                Colors.grey.shade400,
                                Colors.grey.shade500,
                              ] // Grey for read-only admin overrides
                            : hasCustomLocation
                            ? [Colors.green.shade400, Colors.green.shade500]
                            : [Colors.blue.shade400, Colors.blue.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isReadOnly
                                      ? Colors.grey
                                      : hasCustomLocation
                                      ? Colors.green
                                      : Colors.blue)
                                  .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isReadOnly
                                ? Icons
                                      .lock // Lock icon for admin overrides
                                : hasCustomLocation
                                ? Icons.edit_location_alt
                                : Icons.add_location_alt,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isReadOnly
                                    ? 'Admin Override Active'
                                    : hasCustomLocation
                                    ? 'Location Configured'
                                    : 'Set Custom Location',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isReadOnly
                                    ? 'Location set by administrator'
                                    : hasCustomLocation
                                    ? 'Tap to modify on map'
                                    : 'Tap to choose on interactive map',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white.withOpacity(0.8),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (hasCustomLocation) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAdminOverride || isReadOnly
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAdminOverride || isReadOnly
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAdminOverride || isReadOnly
                            ? Icons.admin_panel_settings
                            : Icons.location_on,
                        color: isAdminOverride || isReadOnly
                            ? Colors.red.shade600
                            : Colors.green.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isAdminOverride || isReadOnly
                                    ? Colors.red.shade800
                                    : Colors.green.shade800,
                              ),
                            ),
                            Text(
                              addressText!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isAdminOverride || isReadOnly
                                    ? Colors.red.shade600
                                    : Colors.green.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // Enhanced fixed campus location section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDefaultDay
                        ? [Colors.orange.shade400, Colors.orange.shade500]
                        : [Colors.blue.shade400, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isDefaultDay ? Icons.lock_outlined : Icons.school,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            isDefaultDay
                                ? 'Fixed campus location'
                                : 'Selectable campus',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isDefaultDay && !isAdminOverride && !isReadOnly)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.edit,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        onSelected: (campusId) =>
                            _updateDayLocation(day, campusId),
                        itemBuilder: (context) => campusOptions.map((campus) {
                          // Safe comparison handling different types
                          final currentCampusId = _getCampusIdAsString(
                            dayConfig['campusId'],
                          );
                          final isSelected = campus['id'] == currentCampusId;
                          return PopupMenuItem(
                            value: campus['id'],
                            child: Row(
                              children: [
                                Icon(
                                  Icons.school,
                                  size: 20,
                                  color: isSelected
                                      ? Colors.blue.shade600
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(campus['name'] ?? 'Unknown Campus'),
                                if (isSelected) ...[
                                  const Spacer(),
                                  Icon(
                                    Icons.check,
                                    color: Colors.blue.shade600,
                                    size: 20,
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.indigo.shade600],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveSchedule,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save_outlined, color: Colors.white),
        label: Text(
          _isSaving ? 'Saving Schedule...' : 'Save Weekly Schedule',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
