import 'package:cloud_firestore/cloud_firestore.dart';

class GeofenceProfile {
  final double inLat;
  final double inLng;
  final double inRadius;
  final double outLat;
  final double outLng;
  final double outRadius;
  final String bandType; // "fixed" | "floating"
  final String outsidePolicy; // "block" | "allow_flag"
  final String? outsideMessage;

  GeofenceProfile({
    required this.inLat,
    required this.inLng,
    required this.inRadius,
    required this.outLat,
    required this.outLng,
    required this.outRadius,
    required this.bandType,
    required this.outsidePolicy,
    this.outsideMessage,
  });

  factory GeofenceProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // pull the nested checkInLocation/checkOutLocation maps from Firestore
    final inLoc = data['checkInLocation'] as Map<String, dynamic>;
    final outLoc = data['checkOutLocation'] as Map<String, dynamic>;

    return GeofenceProfile(
      inLat: (inLoc['lat'] as num).toDouble(),
      inLng: (inLoc['lng'] as num).toDouble(),
      inRadius: (inLoc['radius'] as num).toDouble(),
      outLat: (outLoc['lat'] as num).toDouble(),
      outLng: (outLoc['lng'] as num).toDouble(),
      outRadius: (outLoc['radius'] as num).toDouble(),
      bandType: data['bandType'] ?? 'fixed',
      outsidePolicy: data['outsidePolicy'] ?? 'block',
      outsideMessage: data['outsideMessage'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'checkInLocation': {'lat': inLat, 'lng': inLng, 'radius': inRadius},
      'checkOutLocation': {'lat': outLat, 'lng': outLng, 'radius': outRadius},
      'bandType': bandType,
      'outsidePolicy': outsidePolicy,
      'outsideMessage': outsideMessage,
    };
  }
}
