import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AdminIncidentDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const AdminIncidentDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final actualLat = (data['actualLat'] as num?)?.toDouble() ?? 0;
    final actualLng = (data['actualLng'] as num?)?.toDouble() ?? 0;
    final designatedLat = (data['designatedLat'] as num?)?.toDouble() ?? 0;
    final designatedLng = (data['designatedLng'] as num?)?.toDouble() ?? 0;
    final distance = (data['distance'] as num?)?.toDouble() ?? 0;
    final type = (data['type'] ?? '').toString();
    final dateId = (data['dateId'] ?? '').toString();

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('actual'),
        position: LatLng(actualLat, actualLng),
        infoWindow: const InfoWindow(title: 'Actual Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
      Marker(
        markerId: const MarkerId('designated'),
        position: LatLng(designatedLat, designatedLng),
        infoWindow: const InfoWindow(title: 'Designated Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Detail'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(actualLat, actualLng),
                zoom: 15,
              ),
              markers: markers,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${type.toUpperCase()}'),
                Text('Date ID: $dateId'),
                Text('Distance outside: ${distance.toStringAsFixed(1)} m'),
                Text('Actual: ($actualLat,$actualLng)'),
                Text('Designated: ($designatedLat,$designatedLng)'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
