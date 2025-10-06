import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/advanced_geofence_models.dart';
import '../models/geofence_profile_service.dart';
import '../services/org_config_service.dart';

/// Admin geofence profile editor for students
class AdminGeofenceProfileEditor extends StatefulWidget {
  final String studentId;
  final String studentName;

  const AdminGeofenceProfileEditor({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<AdminGeofenceProfileEditor> createState() => _AdminGeofenceProfileEditorState();
}

class _AdminGeofenceProfileEditorState extends State<AdminGeofenceProfileEditor>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<int, DayProfileData> _dayProfiles = {};
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _initializeDayProfiles();
    _loadExistingProfiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeDayProfiles() {
    // Initialize each day with defaults from org config
    for (int day = 0; day <= 6; day++) {
      final defaultCampusId = OrgConfigService.getDefaultCampusForDay(day);
      
      _dayProfiles[day] = DayProfileData(
        dayOfWeek: day,
        hasCustomProfile: false,
        useDefaults: true,
        defaultCampusId: defaultCampusId,
        checkInLocation: LocationData.defaultLocation(),
        checkOutLocation: LocationData.defaultLocation(),
        bandType: BandType.fixed,
        outsidePolicy: OutsidePolicy.block,
        outsideMessage: '',
      );
    }
  }

  Future<void> _loadExistingProfiles() async {
    setState(() => _isLoading = true);
    
    try {
      for (int day = 0; day <= 6; day++) {
        final profile = await GeofenceProfileService.loadGeofenceProfile(
          widget.studentId, 
          day
        );
        
        if (profile != null && mounted) {
          setState(() {
            _dayProfiles[day] = DayProfileData.fromGeofenceProfile(
              profile, 
              _dayProfiles[day]!.defaultCampusId
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profiles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges) {
          return await _showUnsavedChangesDialog();
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Geofence Profile'),
              Text(
                widget.studentName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: List.generate(7, (index) {
              final dayName = OrgConfigService.getDayName(index);
              final hasCustom = _dayProfiles[index]?.hasCustomProfile ?? false;
              
              return Tab(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dayName.substring(0, 3)),
                    if (hasCustom)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          actions: [
            if (_hasUnsavedChanges)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveAllProfiles,
                tooltip: 'Save Changes',
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadExistingProfiles,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: List.generate(7, (index) {
                  return _buildDayProfileEditor(index);
                }),
              ),
        floatingActionButton: _hasUnsavedChanges
            ? FloatingActionButton.extended(
                onPressed: _saveAllProfiles,
                icon: const Icon(Icons.save),
                label: const Text('Save All'),
              )
            : null,
      ),
    );
  }

  Widget _buildDayProfileEditor(int dayOfWeek) {
    final profile = _dayProfiles[dayOfWeek];
    if (profile == null) return const SizedBox.shrink();

    final dayName = OrgConfigService.getDayName(dayOfWeek);


    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Use Defaults Toggle
          Card(
            child: SwitchListTile(
              title: const Text('Use Organization Defaults'),
              subtitle: Text('Default campus: ${profile.defaultCampusId}'),
              value: profile.useDefaults,
              onChanged: (value) {
                setState(() {
                  profile.useDefaults = value;
                  profile.hasCustomProfile = !value;
                  _hasUnsavedChanges = true;
                });
              },
            ),
          ),

          if (!profile.useDefaults) ...[
            const SizedBox(height: 16),

            // Band Type Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Band Type',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<BandType>(
                      segments: const [
                        ButtonSegment(
                          value: BandType.fixed,
                          label: Text('Fixed Band'),
                          icon: Icon(Icons.lock_outline),
                        ),
                        ButtonSegment(
                          value: BandType.floating,
                          label: Text('Floating Band'),
                          icon: Icon(Icons.location_on_outlined),
                        ),
                      ],
                      selected: {profile.bandType},
                      onSelectionChanged: (Set<BandType> selected) {
                        setState(() {
                          profile.bandType = selected.first;
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.bandType == BandType.fixed
                          ? 'Student must be within designated geofence areas'
                          : 'Student may check in/out from anywhere',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Outside Policy (only for Fixed Band)
            if (profile.bandType == BandType.fixed) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Outside Policy',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      RadioListTile<OutsidePolicy>(
                        title: const Text('Block'),
                        subtitle: const Text('Prevent attendance from outside geofence'),
                        value: OutsidePolicy.block,
                        groupValue: profile.outsidePolicy,
                        onChanged: (value) {
                          setState(() {
                            profile.outsidePolicy = value!;
                            _hasUnsavedChanges = true;
                          });
                        },
                      ),
                      RadioListTile<OutsidePolicy>(
                        title: const Text('Allow & Flag'),
                        subtitle: const Text('Allow but create incident report'),
                        value: OutsidePolicy.allowAndFlag,
                        groupValue: profile.outsidePolicy,
                        onChanged: (value) {
                          setState(() {
                            profile.outsidePolicy = value!;
                            _hasUnsavedChanges = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],

            // Check-In Location
            _buildLocationSection(
              'Check-In Location',
              profile.checkInLocation,
              Icons.login,
              Colors.green,
              (location) {
                setState(() {
                  profile.checkInLocation = location;
                  _hasUnsavedChanges = true;
                });
              },
            ),

            const SizedBox(height: 16),

            // Check-Out Location  
            _buildLocationSection(
              'Check-Out Location',
              profile.checkOutLocation,
              Icons.logout,
              Colors.orange,
              (location) {
                setState(() {
                  profile.checkOutLocation = location;
                  _hasUnsavedChanges = true;
                });
              },
            ),

            const SizedBox(height: 16),

            // Outside Message (if Allow & Flag is selected)
            if (profile.bandType == BandType.fixed && 
                profile.outsidePolicy == OutsidePolicy.allowAndFlag) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Outside Message',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Message shown when outside geofence...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        onChanged: (value) {
                          profile.outsideMessage = value;
                          _hasUnsavedChanges = true;
                        },
                        controller: TextEditingController(text: profile.outsideMessage),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ] else ...[
            const SizedBox(height: 16),
            
            // Default Configuration Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default Configuration for $dayName',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.blue),
                      title: Text('Default Campus: ${profile.defaultCampusId}'),
                      subtitle: const Text('Using organization default settings'),
                    ),
                    const Divider(),
                    const ListTile(
                      leading: Icon(Icons.settings, color: Colors.grey),
                      title: Text('Fixed Band • Block Outside'),
                      subtitle: Text('Default organization settings'),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildLocationSection(
    String title,
    LocationData location,
    IconData icon,
    Color color,
    Function(LocationData) onChanged,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campus Preset Selector
            DropdownButtonFormField<String?>(
              decoration: const InputDecoration(
                labelText: 'Campus Preset',
                border: OutlineInputBorder(),
              ),
              value: location.campusPreset,
              items: const [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Custom Location'),
                ),
                DropdownMenuItem<String>(
                  value: 'stony_hill',
                  child: Text('Stony Hill Campus'),
                ),
                DropdownMenuItem<String>(
                  value: 'up_park_camp',
                  child: Text('Up Park Camp'),
                ),
              ],
              onChanged: (campusId) {
                if (campusId == 'stony_hill') {
                  onChanged(LocationData(
                    lat: 18.0179,
                    lng: -76.7491,
                    radiusMeters: 100.0,
                    campusPreset: campusId,
                  ));
                } else if (campusId == 'up_park_camp') {
                  onChanged(LocationData(
                    lat: 17.9778,
                    lng: -76.7947,
                    radiusMeters: 150.0,
                    campusPreset: campusId,
                  ));
                } else {
                  onChanged(location.copyWith(campusPreset: null));
                }
              },
            ),

            const SizedBox(height: 16),

            // Coordinates
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    initialValue: location.lat.toStringAsFixed(6),
                    onChanged: (value) {
                      final lat = double.tryParse(value);
                      if (lat != null) {
                        onChanged(location.copyWith(lat: lat, campusPreset: null));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    initialValue: location.lng.toStringAsFixed(6),
                    onChanged: (value) {
                      final lng = double.tryParse(value);
                      if (lng != null) {
                        onChanged(location.copyWith(lng: lng, campusPreset: null));
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Radius Slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Radius: ${location.radiusMeters.round()}m'),
                Slider(
                  value: location.radiusMeters.clamp(10.0, 1000.0),
                  min: 10.0,
                  max: 1000.0,
                  divisions: 99,
                  label: '${location.radiusMeters.round()}m',
                  onChanged: (value) {
                    onChanged(location.copyWith(radiusMeters: value));
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _getCurrentLocation(onChanged),
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use Current'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showMapPicker(location, onChanged),
                  icon: const Icon(Icons.map),
                  label: const Text('Map'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _getCurrentLocation(Function(LocationData) onChanged) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      onChanged(LocationData(
        lat: position.latitude,
        lng: position.longitude,
        radiusMeters: 100.0,
        campusPreset: null,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated to current position'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMapPicker(LocationData location, Function(LocationData) onChanged) {
    // TODO: Implement map picker dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Map Picker'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map, size: 64),
            SizedBox(height: 16),
            Text('Map integration required'),
            Text('Would show interactive map for location selection'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAllProfiles() async {
    setState(() => _isLoading = true);

    try {
      for (final entry in _dayProfiles.entries) {
        final dayOfWeek = entry.key;
        final profile = entry.value;

        if (profile.hasCustomProfile && !profile.useDefaults) {
        // Save custom profile
        final geofenceProfile = GeofenceProfile(
          dayOfWeek: dayOfWeek,
          userId: widget.studentId,
          bandTypeOverride: profile.bandType,
          outsidePolicy: profile.outsidePolicy,
          outsideMessageText: profile.outsideMessage,
          checkInSlot: GeofenceSlotConfig(
            lat: profile.checkInLocation.lat,
            lng: profile.checkInLocation.lng,
            radiusMeters: profile.checkInLocation.radiusMeters,
          ),
          checkOutSlot: GeofenceSlotConfig(
            lat: profile.checkOutLocation.lat,
            lng: profile.checkOutLocation.lng,
            radiusMeters: profile.checkOutLocation.radiusMeters,
          ),
        );          await GeofenceProfileService.saveGeofenceProfile(geofenceProfile);
        } else if (profile.useDefaults) {
          // Remove custom profile (revert to defaults)
          await GeofenceProfileService.deleteGeofenceProfile(widget.studentId, dayOfWeek);
        }
      }

      setState(() {
        _hasUnsavedChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geofence profiles saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profiles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showUnsavedChangesDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Do you want to save them before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              _saveAllProfiles();
            },
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    ) ?? false;
  }
}

/// Data class for managing day profile state
class DayProfileData {
  int dayOfWeek;
  bool hasCustomProfile;
  bool useDefaults;
  String defaultCampusId;
  LocationData checkInLocation;
  LocationData checkOutLocation;
  BandType bandType;
  OutsidePolicy outsidePolicy;
  String outsideMessage;

  DayProfileData({
    required this.dayOfWeek,
    required this.hasCustomProfile,
    required this.useDefaults,
    required this.defaultCampusId,
    required this.checkInLocation,
    required this.checkOutLocation,
    required this.bandType,
    required this.outsidePolicy,
    required this.outsideMessage,
  });

  factory DayProfileData.fromGeofenceProfile(GeofenceProfile profile, String defaultCampusId) {
    return DayProfileData(
      dayOfWeek: profile.dayOfWeek,
      hasCustomProfile: true,
      useDefaults: false,
      defaultCampusId: defaultCampusId,
      checkInLocation: LocationData(
        lat: profile.checkInSlot?.lat ?? 0.0,
        lng: profile.checkInSlot?.lng ?? 0.0,
        radiusMeters: profile.checkInSlot?.radiusMeters ?? 100.0,
        campusPreset: null,
      ),
      checkOutLocation: LocationData(
        lat: profile.checkOutSlot?.lat ?? 0.0,
        lng: profile.checkOutSlot?.lng ?? 0.0,
        radiusMeters: profile.checkOutSlot?.radiusMeters ?? 100.0,
        campusPreset: null,
      ),
      bandType: profile.bandTypeOverride ?? BandType.fixed,
      outsidePolicy: profile.outsidePolicy ?? OutsidePolicy.block,
      outsideMessage: profile.outsideMessageText ?? '',
    );
  }
}

/// Data class for location information
class LocationData {
  double lat;
  double lng;
  double radiusMeters;
  String? campusPreset;

  LocationData({
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    this.campusPreset,
  });



  factory LocationData.defaultLocation() {
    return LocationData(
      lat: 18.0179,
      lng: -76.7491,
      radiusMeters: 100.0,
      campusPreset: null,
    );
  }

  LocationData copyWith({
    double? lat,
    double? lng,
    double? radiusMeters,
    String? campusPreset,
  }) {
    return LocationData(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      campusPreset: campusPreset ?? this.campusPreset,
    );
  }
}
