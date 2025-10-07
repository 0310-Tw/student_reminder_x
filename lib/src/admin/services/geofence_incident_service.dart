import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/geofence_incident_models.dart';

/// Service for managing geofence incidents
class GeofenceIncidentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _incidentsCollection = 'geofence_incidents';

  /// Create a new geofence incident
  static Future<String> createIncident(GeofenceIncident incident) async {
    try {
      final docRef = await _firestore
          .collection(_incidentsCollection)
          .add(incident.toMap());

      return docRef.id;
    } catch (e) {
      print('Error creating incident: $e');
      rethrow;
    }
  }

  /// Get incidents with filtering options
  static Stream<List<GeofenceIncident>> getIncidents({
    IncidentFilters? filters,
    int limit = 50,
    String? orderBy = 'occurredAt',
    bool descending = true,
  }) {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(
        _incidentsCollection,
      );

      // Apply filters
      if (filters != null) {
        if (filters.dateRange != null) {
          query = query
              .where(
                'occurredAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                  filters.dateRange!.start,
                ),
              )
              .where(
                'occurredAt',
                isLessThanOrEqualTo: Timestamp.fromDate(filters.dateRange!.end),
              );
        }

        if (filters.studentClass != null && filters.studentClass!.isNotEmpty) {
          query = query.where('studentClass', isEqualTo: filters.studentClass);
        }

        if (filters.bandType != null && filters.bandType!.isNotEmpty) {
          query = query.where('bandType', isEqualTo: filters.bandType);
        }

        if (filters.status != null && filters.status!.isNotEmpty) {
          query = query.where('status', isEqualTo: filters.status);
        }

        if (filters.direction != null && filters.direction!.isNotEmpty) {
          query = query.where('direction', isEqualTo: filters.direction);
        }
      }

      // Apply ordering and limit
      query = query.orderBy(orderBy!, descending: descending);
      query = query.limit(limit);

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => GeofenceIncident.fromMap(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      print('Error getting incidents: $e');
      return Stream.value([]);
    }
  }

  /// Get incidents for a specific student
  static Stream<List<GeofenceIncident>> getIncidentsForStudent(
    String studentId, {
    int limit = 20,
  }) {
    try {
      return _firestore
          .collection(_incidentsCollection)
          .where('studentId', isEqualTo: studentId)
          .orderBy('occurredAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => GeofenceIncident.fromMap(doc.data(), doc.id))
                .toList();
          });
    } catch (e) {
      print('Error getting incidents for student $studentId: $e');
      return Stream.value([]);
    }
  }

  /// Get a specific incident by ID
  static Future<GeofenceIncident?> getIncident(String incidentId) async {
    try {
      final doc = await _firestore
          .collection(_incidentsCollection)
          .doc(incidentId)
          .get();

      if (doc.exists && doc.data() != null) {
        return GeofenceIncident.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting incident $incidentId: $e');
      return null;
    }
  }

  /// Update an incident (e.g., acknowledge it)
  static Future<void> updateIncident(
    String incidentId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore
          .collection(_incidentsCollection)
          .doc(incidentId)
          .update(updates);
    } catch (e) {
      print('Error updating incident $incidentId: $e');
      rethrow;
    }
  }

  /// Acknowledge an incident
  static Future<void> acknowledgeIncident(
    String incidentId,
    String acknowledgedBy, {
    String? notes,
  }) async {
    try {
      await updateIncident(incidentId, {
        'status': 'acknowledged',
        'acknowledgedBy': acknowledgedBy,
        'acknowledgedAt': FieldValue.serverTimestamp(),
        'notes': notes,
      });
    } catch (e) {
      print('Error acknowledging incident $incidentId: $e');
      rethrow;
    }
  }

  /// Mark incident as resolved
  static Future<void> resolveIncident(
    String incidentId,
    String resolvedBy, {
    String? notes,
  }) async {
    try {
      await updateIncident(incidentId, {
        'status': 'resolved',
        'resolvedBy': resolvedBy,
        'resolvedAt': FieldValue.serverTimestamp(),
        'notes': notes,
      });
    } catch (e) {
      print('Error resolving incident $incidentId: $e');
      rethrow;
    }
  }

  /// Delete an incident
  static Future<void> deleteIncident(String incidentId) async {
    try {
      await _firestore
          .collection(_incidentsCollection)
          .doc(incidentId)
          .delete();
    } catch (e) {
      print('Error deleting incident $incidentId: $e');
      rethrow;
    }
  }

  /// Get incident statistics
  static Future<IncidentStatistics> getIncidentStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(
        _incidentsCollection,
      );

      if (startDate != null) {
        query = query.where(
          'occurredAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'occurredAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();
      final incidents = snapshot.docs
          .map((doc) => GeofenceIncident.fromMap(doc.data(), doc.id))
          .toList();

      return IncidentStatistics.fromIncidents(incidents);
    } catch (e) {
      print('Error getting incident statistics: $e');
      return const IncidentStatistics(
        totalIncidents: 0,
        pendingIncidents: 0,
        acknowledgedIncidents: 0,
        resolvedIncidents: 0,
        fixedBandIncidents: 0,
        floatingBandIncidents: 0,
        incidentsByDay: {},
        incidentsByStudent: {},
      );
    }
  }

  /// Check for existing incident to prevent duplicates
  static Future<bool> hasRecentIncident(
    String studentId,
    String direction,
    DateTime timestamp, {
    Duration threshold = const Duration(minutes: 5),
  }) async {
    try {
      final startTime = timestamp.subtract(threshold);
      final endTime = timestamp.add(threshold);

      final query = await _firestore
          .collection(_incidentsCollection)
          .where('studentId', isEqualTo: studentId)
          .where('direction', isEqualTo: direction)
          .where('occurredAt', isGreaterThan: Timestamp.fromDate(startTime))
          .where('occurredAt', isLessThan: Timestamp.fromDate(endTime))
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking for recent incident: $e');
      return false;
    }
  }

  /// Bulk operations for multiple incidents
  static Future<void> bulkAcknowledge(
    List<String> incidentIds,
    String acknowledgedBy,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final incidentId in incidentIds) {
        final docRef = _firestore
            .collection(_incidentsCollection)
            .doc(incidentId);

        batch.update(docRef, {
          'status': 'acknowledged',
          'acknowledgedBy': acknowledgedBy,
          'acknowledgedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error bulk acknowledging incidents: $e');
      rethrow;
    }
  }

  /// Get unacknowledged incidents count
  static Future<int> getUnacknowledgedCount() async {
    try {
      final query = await _firestore
          .collection(_incidentsCollection)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      return query.count ?? 0;
    } catch (e) {
      print('Error getting unacknowledged count: $e');
      return 0;
    }
  }
}
