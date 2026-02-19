import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';

class AdminMapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String title;
  final String address;

  const AdminMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(latitude, longitude),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.timetracker.frontend',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(latitude, longitude),
                    width: 80, height: 80,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20, left: 16, right: 16,
            child: PulseCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location Details', style: PulseTextStyles.bodyBold),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on, size: 18, color: PulseColors.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(address, style: PulseTextStyles.body)),
                  ]),
                  const SizedBox(height: 4),
                  Text('$latitude, $longitude', style: PulseTextStyles.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
