import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class IncidentDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const IncidentDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final actualLat = (data['actualLat'] as num?)?.toDouble() ?? 0;
    final actualLng = (data['actualLng'] as num?)?.toDouble() ?? 0;
    final designatedLat = (data['designatedLat'] as num?)?.toDouble() ?? 0;
    final designatedLng = (data['designatedLng'] as num?)?.toDouble() ?? 0;

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
                Text('Type: ${data['type']}'),
                Text('Date ID: ${data['dateId']}'),
                Text('Distance outside: ${(data['distance'] as num?)?.toStringAsFixed(1)} m'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
