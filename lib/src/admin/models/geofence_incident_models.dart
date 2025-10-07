import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Geofence incident model for tracking attendance violations
class GeofenceIncident {
  final String id;
  final String studentId;
  final String studentName;
  final String direction; // 'check_in' or 'check_out'
  final DateTime occurredAt;
  final double distance; // Distance from designated location in meters
  final IncidentLocation designatedLocation;
  final IncidentLocation actualLocation;
  final String bandType; // 'fixed' or 'floating'
  final String status; // 'pending', 'acknowledged', 'resolved'
  final String? messageText;
  final DateTime createdAt;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final String? notes;

  const GeofenceIncident({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.direction,
    required this.occurredAt,
    required this.distance,
    required this.designatedLocation,
    required this.actualLocation,
    required this.bandType,
    required this.status,
    required this.createdAt,
    this.messageText,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.notes,
  });

  /// Create from Firestore document
  factory GeofenceIncident.fromMap(Map<String, dynamic> data, String id) {
    return GeofenceIncident(
      id: id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      direction: data['direction'] ?? 'check_in',
      occurredAt: (data['occurredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      distance: (data['distance'] ?? 0.0).toDouble(),
      designatedLocation: IncidentLocation.fromMap(
        data['designatedLocation'] ?? <String, dynamic>{}
      ),
      actualLocation: IncidentLocation.fromMap(
        data['actualLocation'] ?? <String, dynamic>{}
      ),
      bandType: data['bandType'] ?? 'fixed',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      messageText: data['messageText'],
      acknowledgedBy: data['acknowledgedBy'],
      acknowledgedAt: (data['acknowledgedAt'] as Timestamp?)?.toDate(),
      notes: data['notes'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'direction': direction,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'distance': distance,
      'designatedLocation': designatedLocation.toMap(),
      'actualLocation': actualLocation.toMap(),
      'bandType': bandType,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'messageText': messageText,
      'acknowledgedBy': acknowledgedBy,
      'acknowledgedAt': acknowledgedAt != null ? Timestamp.fromDate(acknowledgedAt!) : null,
      'notes': notes,
    };
  }

  /// Create a copy with updated fields
  GeofenceIncident copyWith({
    String? status,
    String? acknowledgedBy,
    DateTime? acknowledgedAt,
    String? notes,
  }) {
    return GeofenceIncident(
      id: id,
      studentId: studentId,
      studentName: studentName,
      direction: direction,
      occurredAt: occurredAt,
      distance: distance,
      designatedLocation: designatedLocation,
      actualLocation: actualLocation,
      bandType: bandType,
      status: status ?? this.status,
      createdAt: createdAt,
      messageText: messageText,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      notes: notes ?? this.notes,
    );
  }

  /// Get formatted distance string
  String get formattedDistance {
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  /// Check if incident is acknowledged
  bool get isAcknowledged => status == 'acknowledged' || status == 'resolved';

  /// Get status display text
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'acknowledged':
        return 'Acknowledged';
      case 'resolved':
        return 'Resolved';
      default:
        return status.toUpperCase();
    }
  }

  /// Get direction display text
  String get directionDisplay {
    switch (direction) {
      case 'check_in':
        return 'Check In';
      case 'check_out':
        return 'Check Out';
      default:
        return direction.replaceAll('_', ' ').toUpperCase();
    }
  }
}

/// Location information for incident tracking
class IncidentLocation {
  final double lat;
  final double lng;
  final double? radius;
  final String? name;
  final String? address;

  const IncidentLocation({
    required this.lat,
    required this.lng,
    this.radius,
    this.name,
    this.address,
  });

  /// Create from map data
  factory IncidentLocation.fromMap(Map<String, dynamic> data) {
    return IncidentLocation(
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      radius: data['radius']?.toDouble(),
      name: data['name'],
      address: data['address'],
    );
  }

  /// Convert to map data
  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'radius': radius,
      'name': name,
      'address': address,
    };
  }

  /// Get coordinates as string
  String get coordinates => '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
}

/// Filter options for incident list
class IncidentFilters {
  final DateTimeRange? dateRange;
  final String? studentClass;
  final String? bandType; // 'fixed', 'floating', or null for all
  final String? status; // 'pending', 'acknowledged', 'resolved', or null for all
  final String? direction; // 'check_in', 'check_out', or null for all

  const IncidentFilters({
    this.dateRange,
    this.studentClass,
    this.bandType,
    this.status,
    this.direction,
  });

  /// Create copy with updated filters
  IncidentFilters copyWith({
    DateTimeRange? dateRange,
    String? studentClass,
    String? bandType,
    String? status,
    String? direction,
  }) {
    return IncidentFilters(
      dateRange: dateRange ?? this.dateRange,
      studentClass: studentClass ?? this.studentClass,
      bandType: bandType ?? this.bandType,
      status: status ?? this.status,
      direction: direction ?? this.direction,
    );
  }

  /// Check if any filters are active
  bool get hasActiveFilters {
    return dateRange != null ||
           studentClass != null ||
           bandType != null ||
           status != null ||
           direction != null;
  }

  /// Get active filters count
  int get activeFiltersCount {
    int count = 0;
    if (dateRange != null) count++;
    if (studentClass != null && studentClass!.isNotEmpty) count++;
    if (bandType != null && bandType!.isNotEmpty) count++;
    if (status != null && status!.isNotEmpty) count++;
    if (direction != null && direction!.isNotEmpty) count++;
    return count;
  }
}

/// Statistics for geofence incidents
class IncidentStatistics {
  final int totalIncidents;
  final int pendingIncidents;
  final int acknowledgedIncidents;
  final int resolvedIncidents;
  final int fixedBandIncidents;
  final int floatingBandIncidents;
  final Map<String, int> incidentsByDay;
  final Map<String, int> incidentsByStudent;

  const IncidentStatistics({
    required this.totalIncidents,
    required this.pendingIncidents,
    required this.acknowledgedIncidents,
    required this.resolvedIncidents,
    required this.fixedBandIncidents,
    required this.floatingBandIncidents,
    required this.incidentsByDay,
    required this.incidentsByStudent,
  });

  /// Calculate statistics from incidents list
  factory IncidentStatistics.fromIncidents(List<GeofenceIncident> incidents) {
    final incidentsByDay = <String, int>{};
    final incidentsByStudent = <String, int>{};

    int pending = 0;
    int acknowledged = 0;
    int resolved = 0;
    int fixed = 0;
    int floating = 0;

    for (final incident in incidents) {
      // Count by status
      switch (incident.status) {
        case 'pending':
          pending++;
          break;
        case 'acknowledged':
          acknowledged++;
          break;
        case 'resolved':
          resolved++;
          break;
      }

      // Count by band type
      if (incident.bandType == 'fixed') {
        fixed++;
      } else {
        floating++;
      }

      // Count by day
      final dayKey = incident.occurredAt.toIso8601String().substring(0, 10);
      incidentsByDay[dayKey] = (incidentsByDay[dayKey] ?? 0) + 1;

      // Count by student
      incidentsByStudent[incident.studentId] = 
          (incidentsByStudent[incident.studentId] ?? 0) + 1;
    }

    return IncidentStatistics(
      totalIncidents: incidents.length,
      pendingIncidents: pending,
      acknowledgedIncidents: acknowledged,
      resolvedIncidents: resolved,
      fixedBandIncidents: fixed,
      floatingBandIncidents: floating,
      incidentsByDay: incidentsByDay,
      incidentsByStudent: incidentsByStudent,
    );
  }

  /// Get pending incidents percentage
  double get pendingPercentage {
    if (totalIncidents == 0) return 0.0;
    return (pendingIncidents / totalIncidents) * 100;
  }

  /// Get most active day
  String? get mostActiveDay {
    if (incidentsByDay.isEmpty) return null;
    return incidentsByDay.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get most incidents by student
  MapEntry<String, int>? get studentWithMostIncidents {
    if (incidentsByStudent.isEmpty) return null;
    return incidentsByStudent.entries
        .reduce((a, b) => a.value > b.value ? a : b);
  }
}