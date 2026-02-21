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
import 'package:image_picker/image_picker.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../core/widgets/pulse_button.dart';
import 'dart:io';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _nameController = TextEditingController();
  LatLng _officeLocation = const LatLng(51.5, -0.09);
  double _radius = 100.0;
  bool _geofenceEnabled = true;
  bool _payrollEnabled = true;
  bool _isLoading = true;
  final MapController _mapController = MapController();

  final List<String> _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  Set<String> _workingDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  Set<String> _weekendDays = {'Sat', 'Sun'};

  String? _currentLogoUrl;
  String? _currentThemeColor;
  XFile? _selectedLogo;

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
            _currentLogoUrl = settings['companyLogo'];
            _currentThemeColor = settings['themeColor'];
            if (settings['officeLat'] != null && settings['officeLong'] != null) {
              _officeLocation = LatLng(
                (settings['officeLat'] as num).toDouble(),
                (settings['officeLong'] as num).toDouble(),
              );
            }
            _radius = (settings['officeRadiusMeters'] as num?)?.toDouble() ?? 100.0;
             _geofenceEnabled = settings['geofenceEnabled'] != 0;
             _payrollEnabled = settings['payrollEnabled'] != 0;
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
        'geofenceEnabled': _geofenceEnabled ? 1 : 0,
        'payrollEnabled': _payrollEnabled ? 1 : 0,
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

  Future<void> _pickAndUploadLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _isLoading = true;
      _selectedLogo = image;
    });

    try {
      // Extract dominant color
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        FileImage(File(image.path)),
        maximumColorCount: 10,
      );

      final dominantColor = paletteGenerator.dominantColor?.color 
          ?? paletteGenerator.vibrantColor?.color 
          ?? PulseColors.primary;
          
      final hexColor = '#${dominantColor.value.toRadixString(16).substring(2).toUpperCase()}';

      await ApiService.updateBranding(logo: image, themeColor: hexColor);
      PulseColors.setCompanyBrandColor(dominantColor);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Branding updated successfully! Applying new theme...'),
          backgroundColor: PulseColors.success,
        ));
        
        // Force the app to re-evaluate the entire widget tree with the new theme colors
        // by resetting the navigation stack to the admin home.
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/admin', (route) => false);
          }
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update branding: $e')));
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
                  PulseCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.business, color: PulseColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Company Name', style: PulseTextStyles.bodyBold),
                      ]),
                      const SizedBox(height: 10),
                      TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Enter company name')),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // Branding
                  PulseCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.palette, color: PulseColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Text('App Branding & Theme', style: PulseTextStyles.bodyBold),
                      ]),
                      const SizedBox(height: 10),
                      Text('Upload your company logo. The app will automatically extract its dominant color and update the entire application\'s theme for all your employees.', style: PulseTextStyles.caption),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: PulseColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: PulseColors.border),
                              image: _selectedLogo != null 
                                ? DecorationImage(image: FileImage(File(_selectedLogo!.path)), fit: BoxFit.contain)
                                : (_currentLogoUrl != null 
                                    ? DecorationImage(image: NetworkImage(ApiService.getImageUrl(_currentLogoUrl!)), fit: BoxFit.contain)
                                    : null),
                            ),
                            child: (_selectedLogo == null && _currentLogoUrl == null) 
                                ? const Icon(Icons.business, size: 30, color: PulseColors.textHint)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: PulseButton(
                              text: 'Upload Logo',
                              icon: Icons.upload,
                              onPressed: _pickAndUploadLogo,
                            ),
                          ),
                        ],
                      ),
                      if (_currentThemeColor != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('Current Theme Color: ', style: PulseTextStyles.captionBold),
                            Container(
                              width: 20, height: 20,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: PulseColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ],
                        )
                      ],
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
                      SwitchListTile(
                        title: Text('Enable Geofencing restriction', style: PulseTextStyles.bodyBold),
                        subtitle: Text('Users must be within radius to punch in', style: PulseTextStyles.caption),
                        activeColor: PulseColors.primary,
                        contentPadding: EdgeInsets.zero,
                        value: _geofenceEnabled,
                        onChanged: (val) => setState(() => _geofenceEnabled = val),
                      ),
                      if (_geofenceEnabled) ...[
                        const SizedBox(height: 12),
                        Text('Geofence Radius: ${_radius.toInt()} meters', style: PulseTextStyles.caption),
                        Slider(
                          value: _radius, min: 50, max: 1000, divisions: 19,
                          label: '${_radius.toInt()}m',
                          activeColor: PulseColors.primary,
                          onChanged: (val) => setState(() => _radius = val),
                        ),
                      ],
                      const Divider(height: 32),
                      SwitchListTile(
                        title: Text('Enable Payroll & Payslips', style: PulseTextStyles.bodyBold),
                        subtitle: Text('Generate and manage employee payslips', style: PulseTextStyles.caption),
                        activeColor: PulseColors.success,
                        contentPadding: EdgeInsets.zero,
                        value: _payrollEnabled,
                        onChanged: (val) => setState(() => _payrollEnabled = val),
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
