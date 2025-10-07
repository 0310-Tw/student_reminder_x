// lib/src/admin/models/geofence_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../admin/pages/campus_location.dart';

enum BandType { fixed, floating }
enum OutsidePolicy { block, allowAndFlag }

class Geofence {
  final double lat;
  final double lng;
  final double radiusMeters;
  final String? campusSlug;

  Geofence({
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    this.campusSlug,
  });

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'radiusMeters': radiusMeters,
        if (campusSlug != null) 'campusSlug': campusSlug,
      };
}

class EffectiveGeofence {
  final Geofence checkIn;
  final Geofence checkOut;
  final BandType bandType;
  final OutsidePolicy? outsidePolicy;
  final String? outsideMessageText;

  EffectiveGeofence({
    required this.checkIn,
    required this.checkOut,
    required this.bandType,
    this.outsidePolicy,
    this.outsideMessageText,
  });
}

class GeofenceProfile {
  final double inLat;
  final double inLng;
  final double inRadius;
  final double outLat;
  final double outLng;
  final double outRadius;
  final BandType bandType;
  final OutsidePolicy outsidePolicy;
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
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final inLoc = (data['checkInLocation'] ?? {}) as Map<String, dynamic>;
    final outLoc = (data['checkOutLocation'] ?? {}) as Map<String, dynamic>;

    return GeofenceProfile(
      inLat: (inLoc['lat'] ?? 0).toDouble(),
      inLng: (inLoc['lng'] ?? 0).toDouble(),
      inRadius: (inLoc['radius'] ?? 100).toDouble(),
      outLat: (outLoc['lat'] ?? 0).toDouble(),
      outLng: (outLoc['lng'] ?? 0).toDouble(),
      outRadius: (outLoc['radius'] ?? 100).toDouble(),
      bandType: _parseBandType(data['bandType']),
      outsidePolicy: _parsePolicy(data['outsidePolicy']),
      outsideMessage: data['outsideMessage'],
    );
  }

  Map<String, dynamic> toMap() => {
        'checkInLocation': {
          'lat': inLat,
          'lng': inLng,
          'radius': inRadius,
        },
        'checkOutLocation': {
          'lat': outLat,
          'lng': outLng,
          'radius': outRadius,
        },
        'bandType': bandType.name,
        'outsidePolicy': outsidePolicy.name,
        'outsideMessage': outsideMessage,
      };

  static BandType _parseBandType(String? value) {
    switch (value) {
      case 'floating':
        return BandType.floating;
      default:
        return BandType.fixed;
    }
  }

  static OutsidePolicy _parsePolicy(String? value) {
    switch (value) {
      case 'allow_flag':
      case 'allowAndFlag':
        return OutsidePolicy.allowAndFlag;
      default:
        return OutsidePolicy.block;
    }
  }

  // 🔥 Resolves effective geofence for today if profile or defaults missing
  static EffectiveGeofence resolve({
    required int dow, // 0 = Sunday
  }) {
    final slug = (dow == 3 || dow == 4) ? "stony_hill" : "up_park_camp";
    final campus = campusLocations[slug]!;

    final defaultGeo = Geofence(
      lat: campus.latitude,
      lng: campus.longitude,
      radiusMeters: campus.radiusMeters,
      campusSlug: slug,
    );

    return EffectiveGeofence(
      checkIn: defaultGeo,
      checkOut: defaultGeo,
      bandType: BandType.fixed,
      outsidePolicy: OutsidePolicy.block,
      outsideMessageText: null,
    );
  }
}
