class CampusLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  CampusLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });
}

final Map<String, CampusLocation> campusLocations = {
  "up_park_camp": CampusLocation(
    id: "up_park_camp",
    name: "Up Park Camp",
    latitude: 18.0123,
    longitude: -76.7890,
    radiusMeters: 100,
  ),
  "stony_hill": CampusLocation(
    id: "stony_hill",
    name: "Stony Hill Campus",
    latitude: 18.1234,
    longitude: -76.8765,
    radiusMeters: 100,
  ),
};
