// lib/src/models/geofence_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class GeofenceLocation {
  final double lat;
  final double lng;
  final double radius; // meters

  GeofenceLocation({
    required this.lat,
    required this.lng,
    required this.radius,
  });

  factory GeofenceLocation.fromMap(Map<String, dynamic> data) {
    return GeofenceLocation(
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      radius: (data['radius'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'radius': radius,
    };
  }
}

class GeofenceProfile {
  final GeofenceLocation checkInLocation;
  final GeofenceLocation checkOutLocation;
  final String bandType; // "fixed" | "floating"
  final String outsidePolicy; // "block" | "allow_flag"
  final String? outsideMessage;

  GeofenceProfile({
    required this.checkInLocation,
    required this.checkOutLocation,
    required this.bandType,
    required this.outsidePolicy,
    this.outsideMessage,
  });

  factory GeofenceProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GeofenceProfile(
      checkInLocation: GeofenceLocation.fromMap(data['checkInLocation']),
      checkOutLocation: GeofenceLocation.fromMap(data['checkOutLocation']),
      bandType: data['bandType'] ?? 'fixed',
      outsidePolicy: data['outsidePolicy'] ?? 'block',
      outsideMessage: data['outsideMessage'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'checkInLocation': checkInLocation.toMap(),
      'checkOutLocation': checkOutLocation.toMap(),
      'bandType': bandType,
      'outsidePolicy': outsidePolicy,
      'outsideMessage': outsideMessage,
    };
  }
}
