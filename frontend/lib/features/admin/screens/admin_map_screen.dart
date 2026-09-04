// --- 9. The Location Verification Map ---
// This is a utility screen. When an Admin clicks on an attendance record, 
// they are brought here to see exactly where on the map that person was 
// standing when they punched in.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/core/theme/pulse_colors.dart';
import 'package:frontend/core/theme/pulse_text_styles.dart';
import 'package:frontend/core/widgets/pulse_card.dart';

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
              // Center the map on the employee's coordinates
              initialCenter: LatLng(latitude, longitude),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.pulsehub.timetracker',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  // The "Pin" on the map
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
                    Icon(Icons.location_on, size: 18, color: PulseColors.accent),
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
