import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:students_reminder/src/features/geofence/geofence_service.dart';

import '../../services/auth_service.dart';
import '../../shared/routes.dart';
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
                  if (!dayConfig.containsKey('campusId') ||
                      dayConfig['campusId'] is! String) {
                    dayConfig['campusId'] =
                        day == 'wednesday' || day == 'thursday'
                        ? 'stony_hill'
                        : 'up_park_camp';
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

  Future<void> _saveSchedule() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      if (mounted) {
        setState(() => _isSaving = true);
      }

      // Save weekly schedule
      await FirebaseFirestore.instance
          .collection('student_schedules')
          .doc(user.uid)
          .set({
            'weeklySchedule': _weeklySchedule,
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

      final geofences = await GeofenceService.instance.getAllGeofences(
        user.uid,
      );

      if (mounted) {
        setState(() {
          // Update weekly schedule with loaded geofences
          for (final entry in geofences.entries) {
            final day = entry.key;
            final geofenceData = entry.value;

            if (_weeklySchedule.containsKey(day)) {
              final dayConfig = _weeklySchedule[day] as Map<String, dynamic>;

              // Only update if this is a custom day
              if (dayConfig['type'] == 'custom') {
                dayConfig['customLocation'] = {
                  'lat': geofenceData['lat'],
                  'lng': geofenceData['lng'],
                  'radius': geofenceData['radius'],
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

      // Save custom locations as geofences
      for (final entry in _weeklySchedule.entries) {
        final day = entry.key;
        final dayConfig = entry.value as Map<String, dynamic>;

        // Only save geofences for custom days and Monday-Friday
        if (dayConfig['type'] == 'custom' &&
            GeofenceService.isValidDay(day) &&
            dayConfig['customLocation'] != null) {
          final customLoc = dayConfig['customLocation'] as Map<String, dynamic>;
          final lat = _extractDouble(customLoc['lat']);
          final lng = _extractDouble(customLoc['lng']);
          final radius = _extractDouble(customLoc['radius']);

          if (lat != null && lng != null && radius != null) {
            await GeofenceService.instance.saveGeofence(
              user.uid,
              day,
              lat,
              lng,
              radius,
            );
          }
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
    LatLng? initialLocation;
    double initialRadius = 100.0;

    // Get existing custom location if available
    if (dayConfig['customLocation'] != null) {
      final customLoc = dayConfig['customLocation'] as Map<String, dynamic>;
      initialLocation = LatLng(
        customLoc['lat'] as double,
        customLoc['lng'] as double,
      );
      initialRadius = (customLoc['radius'] as num?)?.toDouble() ?? 100.0;
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
    final isDefaultDay = day == 'wednesday' || day == 'thursday';

    String displayName;
    String? addressText;
    bool hasCustomLocation = false;

    if (isCustomDay && dayConfig['customLocation'] != null) {
      final customLoc = dayConfig['customLocation'] as Map<String, dynamic>;
      final lat = (customLoc['lat'] as double).toStringAsFixed(4);
      final lng = (customLoc['lng'] as double).toStringAsFixed(4);
      final radius = (customLoc['radius'] as num).toInt();
      displayName = 'Custom Location Set';

      // Use address if available, otherwise show coordinates
      if (customLoc['address'] != null &&
          customLoc['address'].toString().isNotEmpty) {
        addressText = '📍 ${customLoc['address']} (${radius}m radius)';
      } else {
        addressText = '📍 Lat: $lat, Lng: $lng (${radius}m radius)';
      }
      hasCustomLocation = true;
    } else {
      // Safe type handling for campusId
      final campusIdValue = dayConfig['campusId'];
      final selectedCampusId = campusIdValue is String
          ? campusIdValue
          : (campusIdValue is Map && campusIdValue['id'] != null)
          ? campusIdValue['id'].toString()
          : 'up_park_camp'; // fallback default

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
          colors: isCustomDay
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
                (isCustomDay
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
                (isCustomDay
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
                      colors: isCustomDay
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
                        (isCustomDay
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
                        isCustomDay
                            ? Icons.my_location
                            : isDefaultDay
                            ? Icons.location_on
                            : Icons.school,
                        size: 14,
                        color: isCustomDay
                            ? Colors.green.shade600
                            : isDefaultDay
                            ? Colors.orange.shade600
                            : Colors.blue.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCustomDay
                            ? 'Flexible'
                            : isDefaultDay
                            ? 'Fixed'
                            : 'Campus',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCustomDay
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
            const SizedBox(height: 16),

            if (isCustomDay) ...[
              // Enhanced custom location section
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: InkWell(
                  onTap: () => _openLocationPicker(day),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hasCustomLocation
                            ? [Colors.green.shade400, Colors.green.shade500]
                            : [Colors.blue.shade400, Colors.blue.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (hasCustomLocation ? Colors.green : Colors.blue)
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
                            hasCustomLocation
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
                                hasCustomLocation
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
                                hasCustomLocation
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
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.green.shade600,
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
                                color: Colors.green.shade800,
                              ),
                            ),
                            Text(
                              addressText!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade600,
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
                    if (!isDefaultDay)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.edit,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        onSelected: (campusId) =>
                            _updateDayLocation(day, campusId),
                        itemBuilder: (context) => campusOptions.map((campus) {
                          // Safe comparison handling different types
                          final campusIdValue = dayConfig['campusId'];
                          final currentCampusId = campusIdValue is String
                              ? campusIdValue
                              : (campusIdValue is Map &&
                                    campusIdValue['id'] != null)
                              ? campusIdValue['id'].toString()
                              : '';
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
