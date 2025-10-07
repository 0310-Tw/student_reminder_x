import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/admin/pages/admin_geofence_editor.dart';
import 'package:students_reminder/src/admin/models/comprehensive_geofence_resolver.dart';

class EnhancedAdminGeofencePage extends StatefulWidget {
  const EnhancedAdminGeofencePage({super.key});

  @override
  State<EnhancedAdminGeofencePage> createState() =>
      _EnhancedAdminGeofencePageState();
}

class _EnhancedAdminGeofencePageState extends State<EnhancedAdminGeofencePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String? selectedUserId;
  List<Map<String, dynamic>> allUsers = [];
  bool isLoading = true;

  // Real statistics
  int totalUsers = 0;
  int activeGeofences = 0;
  int customLocations = 0;
  int overrides = 0;

  final ComprehensiveGeofenceResolver _comprehensiveGeofenceResolver =
      ComprehensiveGeofenceResolver.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('lastName')
          .get();

      // Calculate real statistics by checking geofence_profiles subcollection
      int usersWithGeofences = 0;
      int totalCustomLocations = 0;

      for (var doc in snapshot.docs) {
        try {
          final geofenceProfilesSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(doc.id)
              .collection('geofence_profiles')
              .get();

          if (geofenceProfilesSnapshot.docs.isNotEmpty) {
            usersWithGeofences++;
            totalCustomLocations += geofenceProfilesSnapshot.docs.length;
          }
        } catch (e) {
          // Skip if error reading geofence profiles
        }
      }

      setState(() {
        allUsers = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}',
            'email': data['email'] ?? '',
            'role': data['role'] ?? 'student',
          };
        }).toList();

        // Update real statistics
        totalUsers = allUsers.length;
        activeGeofences = usersWithGeofences;
        customLocations = totalCustomLocations;
        overrides = 0; // Could be calculated from admin overrides if needed

        isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        title: Text('Enhanced Geofence Management'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.person_pin), text: 'Profiles'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildOverviewTab(), _buildCustomLocationsTab()],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading statistics...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  totalUsers.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active Geofences',
                  activeGeofences.toString(),
                  Icons.location_on,
                  Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Custom Locations',
                  customLocations.toString(),
                  Icons.place,
                  Colors.orange,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Overrides',
                  overrides.toString(),
                  Icons.compare_arrows,
                  Colors.purple,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          // Additional content can be added here
        ],
      ),
    );
  }

  Widget _buildCustomLocationsTab() {
    return Column(
      children: [
        // User Selection
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete Student Geofence Profile',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Shows set days, fallback locations, and student customizations',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedUserId,
                    hint: Text('Choose a student to view complete profile...'),
                    items: allUsers
                        .where((user) => user['role'] == 'student')
                        .map((user) {
                          return DropdownMenuItem<String>(
                            value: user['id'],
                            child: Text('${user['name']} (${user['email']})'),
                          );
                        })
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedUserId = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Comprehensive Profile View
        Expanded(
          child: selectedUserId == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_city, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Select a student to view their complete geofence profile',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Set Days (Wed/Thu)\n• Fallback Locations\n• Student Custom Locations',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _buildComprehensiveGeofenceProfile(selectedUserId!),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComprehensiveGeofenceProfile(String userId) {
    return FutureBuilder<ComprehensiveGeofenceProfile>(
      future: _comprehensiveGeofenceResolver.getStudentComprehensiveProfile(
        userId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No geofence profile found'));
        }

        final profile = snapshot.data!;
        final selectedUser = allUsers.firstWhere(
          (user) => user['id'] == userId,
        );

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ' ${selectedUser['name']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Active locations grouped by day
                  Text(
                    'Active Locations by Day:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._groupLocationsByDay(profile.locations).entries.map(
                    (entry) => _buildDayLocations(entry.key, entry.value),
                  ),

                  const SizedBox(height: 16),

                  // Summary stats
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, List<GeofenceLocationInfo>> _groupLocationsByDay(
    List<GeofenceLocationInfo> locations,
  ) {
    final Map<String, List<GeofenceLocationInfo>> grouped = {};

    final allDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

    for (final day in allDays) {
      grouped[day] = locations.where((l) => l.day == day).toList();
    }

    return grouped;
  }

  Widget _buildDayLocations(String day, List<GeofenceLocationInfo> locations) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showDayLocationOptions(day, selectedUserId!),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Text(
                    '${_formatDay(day)}:',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Icon(Icons.edit, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to Override',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (locations.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: GestureDetector(
                onTap: () => _showAddLocationDialog(day, selectedUserId!),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_location, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to add location for this day',
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...locations.map((location) => _buildLocationItem(location)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLocationItem(GeofenceLocationInfo location) {
    Color color = _getLocationSourceColor(location.source);

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: GestureDetector(
        onTap: () => _showEditLocationDialog(location, selectedUserId!),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location.description,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Text(
                _formatLocationSource(location.source),
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDay(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 'Monday';
      case 'tuesday':
        return 'Tuesday';
      case 'wednesday':
        return 'Wednesday';
      case 'thursday':
        return 'Thursday';
      case 'friday':
        return 'Friday';
      default:
        return day;
    }
  }

  Color _getLocationSourceColor(LocationSource source) {
    switch (source) {
      case LocationSource.setDay:
        return Colors.green;
      case LocationSource.fallback:
        return Colors.orange;
      case LocationSource.studentCustom:
        return Colors.blue;
    }
  }

  String _formatLocationSource(LocationSource source) {
    switch (source) {
      case LocationSource.setDay:
        return 'Set Day';
      case LocationSource.fallback:
        return 'Fallback';
      case LocationSource.studentCustom:
        return 'Student Custom';
    }
  }

  // Admin Override Methods
  Future<void> _showDayLocationOptions(String day, String userId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDayOverrideSheet(day, userId),
    );
  }

  Widget _buildDayOverrideSheet(String day, String userId) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Override ${_formatDay(day)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose how to set the location for this day',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Options
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildOverrideOption(
                      'Set to Campus Location',
                      'Use the default campus location for this day',
                      Icons.location_city,
                      Colors.green,
                      () => _setDayLocation(day, userId, LocationSource.setDay),
                    ),
                    const SizedBox(height: 12),
                    _buildOverrideOption(
                      'Set to Fallback Location',
                      'Use the fallback campus location',
                      Icons.backup,
                      Colors.orange,
                      () =>
                          _setDayLocation(day, userId, LocationSource.fallback),
                    ),
                    const SizedBox(height: 12),
                    _buildOverrideOption(
                      'Set Custom Location',
                      'Choose a specific location for this student',
                      Icons.place,
                      Colors.blue,
                      () => _showCustomLocationPicker(day, userId),
                    ),
                    const SizedBox(height: 12),
                    _buildOverrideOption(
                      'Clear All Locations',
                      'Remove all location settings for this day',
                      Icons.clear,
                      Colors.red,
                      () => _clearDayLocations(day, userId),
                    ),
                    const SizedBox(height: 12),
                    _buildOverrideOption(
                      'Add Additional Location',
                      'Add another location option for this day',
                      Icons.add_location,
                      Colors.purple,
                      () => _showAddLocationDialog(day, userId),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverrideOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditLocationDialog(
    GeofenceLocationInfo location,
    String userId,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${_formatDay(location.day)} Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current: ${location.description}'),
            const SizedBox(height: 8),
            Text('Source: ${_formatLocationSource(location.source)}'),
            const SizedBox(height: 16),
            Text('What would you like to do?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showCustomLocationPicker(location.day, userId);
            },
            child: const Text('Change Location'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeLocationOverride(location, userId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddLocationDialog(String day, String userId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Location for ${_formatDay(day)}'),
        content: const Text('Choose the type of location to add:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _setDayLocation(day, userId, LocationSource.setDay);
            },
            child: const Text('Campus Location'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _setDayLocation(day, userId, LocationSource.fallback);
            },
            child: const Text('Fallback Location'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showCustomLocationPicker(day, userId);
            },
            child: const Text('Custom Location'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomLocationPicker(String day, String userId) async {
    // Navigate to location picker or show map dialog
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AdminGeofenceEditor(studentId: userId, dateId: day),
      ),
    );

    if (result == true) {
      // Refresh the profile
      setState(() {});
    }
  }

  Future<void> _setDayLocation(
    String day,
    String userId,
    LocationSource source,
  ) async {
    try {
      // Get user document
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);

      // Define default locations based on source type
      Map<String, double> coordinates;
      String description;

      switch (source) {
        case LocationSource.setDay:
          coordinates = {
            'latitude': 18.0179,
            'longitude': -76.8099,
          }; // UTech campus
          description = 'UTech Campus - ${_formatDay(day)}';
          break;
        case LocationSource.fallback:
          coordinates = {
            'latitude': 18.0179,
            'longitude': -76.8099,
          }; // Same as campus for now
          description = 'Fallback Campus Location';
          break;
        case LocationSource.studentCustom:
          // This should go through custom location picker
          return;
      }

      // Update or create geofence profile for this day
      await userDoc.collection('geofence_profiles').doc(day).set({
        'dayOfWeek': day,
        'latitude': coordinates['latitude'],
        'longitude': coordinates['longitude'],
        'radius': 100.0,
        'description': description,
        'isEnabled': true,
        'source': source.toString().split('.').last,
        'lastModified': FieldValue.serverTimestamp(),
        'modifiedBy': 'admin_override',
      });

      Navigator.pop(context); // Close bottom sheet

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_formatDay(day)} location updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the profile
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearDayLocations(String day, String userId) async {
    try {
      // Delete the geofence profile for this day
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('geofence_profiles')
          .doc(day)
          .delete();

      Navigator.pop(context); // Close bottom sheet

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_formatDay(day)} locations cleared successfully'),
          backgroundColor: Colors.orange,
        ),
      );

      // Refresh the profile
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing locations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeLocationOverride(
    GeofenceLocationInfo location,
    String userId,
  ) async {
    try {
      // If this is an admin override, we can remove it
      // For now, we'll delete the entire day's configuration
      // In a more complex system, you might want to handle multiple locations per day
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('geofence_profiles')
          .doc(location.day)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location override removed successfully'),
          backgroundColor: Colors.orange,
        ),
      );

      // Refresh the profile
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing override: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
