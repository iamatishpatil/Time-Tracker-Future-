import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';
import '../../core/widgets/pulse_shimmer.dart';
import '../../services/api_service.dart';
import 'admin_holidays_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _nameController = TextEditingController();
  LatLng _officeLocation = const LatLng(51.5, -0.09);
  double _radius = 100.0;
  bool _isLoading = true;
  final MapController _mapController = MapController();

  final List<String> _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  Set<String> _workingDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  Set<String> _weekendDays = {'Sat', 'Sun'};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await ApiService.getSettings();
      if (settings.isNotEmpty) {
        if (mounted) {
          setState(() {
            _nameController.text = settings['companyName'] ?? '';
            if (settings['officeLat'] != null && settings['officeLong'] != null) {
              _officeLocation = LatLng(settings['officeLat'], settings['officeLong']);
            }
            _radius = (settings['officeRadiusMeters'] as num?)?.toDouble() ?? 100.0;
            if (settings['workingDays'] != null) {
              try {
                final wd = settings['workingDays'];
                if (wd is String) {
                  _workingDays = Set<String>.from(wd.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',').map((e) => e.trim()));
                } else if (wd is List) {
                  _workingDays = Set<String>.from(wd.map((e) => e.toString()));
                }
              } catch (_) {}
            }
            if (settings['weekendDays'] != null) {
              try {
                final wk = settings['weekendDays'];
                if (wk is String) {
                  _weekendDays = Set<String>.from(wk.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',').map((e) => e.trim()));
                } else if (wk is List) {
                  _weekendDays = Set<String>.from(wk.map((e) => e.toString()));
                }
              } catch (_) {}
            }
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(_officeLocation, 15);
          });
        }
      } else {
        _getCurrentLocation();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _getCurrentLocation();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _officeLocation = LatLng(position.latitude, position.longitude));
        _mapController.move(_officeLocation, 15);
      }
    } catch (e) {}
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.updateSettings({
        'companyName': _nameController.text,
        'officeLat': _officeLocation.latitude,
        'officeLong': _officeLocation.longitude,
        'officeRadiusMeters': _radius,
        'workingDays': _workingDays.toList(),
        'weekendDays': _weekendDays.toList(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings Saved!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.beach_access),
            tooltip: 'Manage Holidays',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminHolidaysScreen())),
          ),
        ],
      ),
      body: _isLoading
          ? Padding(padding: const EdgeInsets.all(20), child: PulseShimmer.list(count: 3, itemHeight: 60))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Company Name
                  PulseCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.business, color: PulseColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Company Name', style: PulseTextStyles.bodyBold),
                      ]),
                      const SizedBox(height: 10),
                      TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Enter company name')),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // Working Days
                  PulseCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.work_outline, color: PulseColors.success, size: 20),
                        const SizedBox(width: 8),
                        Text('Working Days', style: PulseTextStyles.bodyBold),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: _allDays.map((day) {
                          final isWorking = _workingDays.contains(day);
                          return FilterChip(
                            label: Text(day, style: TextStyle(color: isWorking ? Colors.white : PulseColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                            selected: isWorking,
                            selectedColor: PulseColors.success,
                            backgroundColor: PulseColors.surfaceVariant,
                            checkmarkColor: Colors.white,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) { _workingDays.add(day); _weekendDays.remove(day); } else { _workingDays.remove(day); }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // Weekend Days
                  PulseCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.weekend, color: PulseColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Text('Weekend Days', style: PulseTextStyles.bodyBold),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: _allDays.map((day) {
                          final isWeekend = _weekendDays.contains(day);
                          return FilterChip(
                            label: Text(day, style: TextStyle(color: isWeekend ? Colors.white : PulseColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                            selected: isWeekend,
                            selectedColor: PulseColors.warning,
                            backgroundColor: PulseColors.surfaceVariant,
                            checkmarkColor: Colors.white,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) { _weekendDays.add(day); _workingDays.remove(day); } else { _weekendDays.remove(day); }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // Office Location
                  PulseCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.location_on, color: PulseColors.error, size: 20),
                        const SizedBox(width: 8),
                        Text('Office Location & Radius', style: PulseTextStyles.bodyBold),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: PulseColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _officeLocation,
                              initialZoom: 15.0,
                              onTap: (tapPosition, point) => setState(() => _officeLocation = point),
                            ),
                            children: [
                              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.timetracker.frontend'),
                              CircleLayer(circles: [
                                CircleMarker(point: _officeLocation, color: PulseColors.primary.withOpacity(0.25), borderStrokeWidth: 2, borderColor: PulseColors.primary, radius: _radius, useRadiusInMeter: true),
                              ]),
                              MarkerLayer(markers: [
                                Marker(point: _officeLocation, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40)),
                              ]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Geofence Radius: ${_radius.toInt()} meters', style: PulseTextStyles.caption),
                      Slider(
                        value: _radius, min: 50, max: 1000, divisions: 19,
                        label: '${_radius.toInt()}m',
                        activeColor: PulseColors.primary,
                        onChanged: (val) => setState(() => _radius = val),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PulseColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
