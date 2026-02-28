import 'package:cached_network_image/cached_network_image.dart';
// --- 7. The Control Tower (Settings) ---
// This is the most powerful screen for the Admin. It controls the "Rules of the Game":
// 1. Where the office is (Geofencing)
// 2. What the app looks like (Dynamic Branding)
// 3. Which features are active (Payroll toggle)

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/branding_provider.dart';
import '../../core/widgets/pulse_app_bar.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  final bool isTab;
  const AdminSettingsScreen({super.key, this.isTab = false});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  LatLng _officeLocation = const LatLng(51.5, -0.09);
  double _radius = 100.0;
  bool _geofenceEnabled = true;
  bool _payrollEnabled = true;
  bool _cameraAuthEnabled = true;
  bool _isLoading = true;
  final MapController _mapController = MapController();

  final List<String> _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  Set<String> _workingDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  Set<String> _weekendDays = {'Sat', 'Sun'};

  String? _currentLogoUrl;
  String? _currentThemeColor;
  String? _secondaryColor;
  String? _accentColor;
  XFile? _selectedLogo;

  @override
  void initState() {
    super.initState();
    _latController.text = _officeLocation.latitude.toString();
    _lngController.text = _officeLocation.longitude.toString();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
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
            _secondaryColor = settings['secondaryColor'];
            _accentColor = settings['accentColor'];
            if (settings['officeLat'] != null && settings['officeLong'] != null) {
              _officeLocation = LatLng(
                (settings['officeLat'] as num).toDouble(),
                (settings['officeLong'] as num).toDouble(),
              );
              _latController.text = _officeLocation.latitude.toString();
              _lngController.text = _officeLocation.longitude.toString();
            } else {
              // ANR/Bug Fix: If DB has no location, fetch GPS. Otherwise it defaults to London and locks everyone out.
              _getCurrentLocation();
            }
            _radius = (settings['officeRadiusMeters'] as num?)?.toDouble() ?? 100.0;
             _geofenceEnabled = settings['geofenceEnabled'] != 0;
             _payrollEnabled = settings['payrollEnabled'] != 0;
             _cameraAuthEnabled = settings['cameraAuthEnabled'] != 0;
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
        setState(() {
          _officeLocation = LatLng(position.latitude, position.longitude);
          _latController.text = _officeLocation.latitude.toString();
          _lngController.text = _officeLocation.longitude.toString();
        });
        _mapController.move(_officeLocation, 15);
      }
    } catch (e) {}
  }

  Future<void> _saveSettings({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      await ApiService.updateSettings({
        'companyName': _nameController.text.trim(),
        'officeLat': _officeLocation.latitude,
        'officeLong': _officeLocation.longitude,
        'officeRadiusMeters': _radius,
        'geofenceEnabled': _geofenceEnabled ? 1 : 0,
        'payrollEnabled': _payrollEnabled ? 1 : 0,
        'cameraAuthEnabled': _cameraAuthEnabled ? 1 : 0,
        'workingDays': _workingDays.toList(),
        'weekendDays': _weekendDays.toList(),
        'themeColor': _currentThemeColor,
        'secondaryColor': _secondaryColor,
        'accentColor': _accentColor,
      });
      
      // Update local branding provider only if this is a manual save (button click).
      // Toggles save in 'silent' mode and DO NOT need to re-trigger heavy UI palette generation.
      if (!silent && _currentThemeColor != null) {
        final pColor = Color(int.parse(_currentThemeColor!.replaceAll('#', 'FF'), radix: 16));
        final sColor = _secondaryColor != null ? Color(int.parse(_secondaryColor!.replaceAll('#', 'FF'), radix: 16)) : pColor;
        final aColor = _accentColor != null ? Color(int.parse(_accentColor!.replaceAll('#', 'FF'), radix: 16)) : PulseColors.accent;
        
        await ref.read(brandingProvider.notifier).updateBranding(
          _currentLogoUrl, 
          pColor, 
          secondary: sColor, 
          accent: aColor,
          companyName: _nameController.text.trim()
        );
      }
      
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings Saved!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (!silent && mounted) setState(() => _isLoading = false);
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
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        FileImage(File(image.path)),
        maximumColorCount: 10,
      );

      final dominantColor = paletteGenerator.dominantColor?.color 
          ?? paletteGenerator.vibrantColor?.color 
          ?? PulseColors.primary;
          
      final hexColor = '#${dominantColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

      final response = await ApiService.updateBranding(
        logo: image, 
        themeColor: hexColor,
        secondaryColor: hexColor, 
      );
      
      // Real-time branding update via provider
      await ref.read(brandingProvider.notifier).updateBranding(
        response['logo'],
        dominantColor,
        secondary: dominantColor,
        companyName: _nameController.text.trim(),
      );
      
      setState(() {
        _currentThemeColor = hexColor;
        _secondaryColor = hexColor;
        _currentLogoUrl = response['logo'];
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Branding updated successfully! Applying new theme...'),
          backgroundColor: PulseColors.success,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update branding: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
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

                // Branding Section (Modularized)
                _LogoUploadWidget(
                  logoUrl: _currentLogoUrl,
                  selectedLogo: _selectedLogo,
                  onPickLogo: _pickAndUploadLogo,
                ),
                const SizedBox(height: 14),
                
                _BrandingPaletteWidget(
                  currentThemeColor: _currentThemeColor,
                  secondaryColor: _secondaryColor,
                  accentColor: _accentColor,
                  onPrimaryPicked: (hex) => setState(() => _currentThemeColor = hex),
                  onSecondaryPicked: (hex) => setState(() => _secondaryColor = hex),
                  onAccentPicked: (hex) => setState(() => _accentColor = hex),
                  showColorPickerDialog: _showColorPickerDialog,
                  showPaletteActionDialog: _showPaletteActionDialog,
                ),
                const SizedBox(height: 24),

                // Live Preview Section (The "Dream11" touch)
                Text('LIVE BRANDING PREVIEW', style: PulseTextStyles.captionBold.copyWith(letterSpacing: 1.5)),
                const SizedBox(height: 12),
                PulseCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 24,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: PulseColors.meshGradient,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 20, left: 20,
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            backgroundImage: _currentLogoUrl != null ? CachedNetworkImageProvider(ApiService.getImageUrl(_currentLogoUrl!)) : null,
                            child: _currentLogoUrl == null ? Icon(Icons.business, color: PulseColors.primary) : null,
                          ),
                        ),
                        Positioned(
                          bottom: 20, left: 20, right: 20,
                          child: PulseCard(
                            glassEffect: true,
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(width: 40, height: 40, decoration: BoxDecoration(color: PulseColors.primary, shape: BoxShape.circle)),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(width: 80, height: 8, decoration: BoxDecoration(color: PulseColors.textPrimary, borderRadius: BorderRadius.circular(4))),
                                  const SizedBox(height: 6),
                                  Container(width: 120, height: 6, decoration: BoxDecoration(color: PulseColors.textSecondary.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4))),
                                ])),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Working Days
                PulseCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.work_outline, color: PulseColors.success, size: 20),
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
                      Icon(Icons.weekend, color: PulseColors.warning, size: 20),
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

                // --- The Office Map & Geofencing ---
                PulseCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.location_on, color: PulseColors.error, size: 20),
                      const SizedBox(width: 8),
                      Text('Office Location & Radius', style: PulseTextStyles.bodyBold),
                    ]),
                    const SizedBox(height: 12),
                    // The interactive map
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
                            onTap: (tapPosition, point) => setState(() {
                              _officeLocation = point;
                              _latController.text = point.latitude.toString();
                              _lngController.text = point.longitude.toString();
                            }),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                              subdomains: const ['a', 'b', 'c', 'd'],
                              userAgentPackageName: 'com.pulsehub.timetracker',
                              maxZoom: 19,
                            ),
                            // This circle shows the "Allowed Area" for check-ins
                            CircleLayer(circles: [
                              CircleMarker(point: _officeLocation, color: PulseColors.primary.withValues(alpha: 0.25), borderStrokeWidth: 2, borderColor: PulseColors.primary, radius: _radius, useRadiusInMeter: true),
                            ]),
                            MarkerLayer(markers: [
                              Marker(point: _officeLocation, width: 40, height: 40, child: Icon(Icons.location_on, color: PulseColors.error, size: 40)),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Manual Coordinate Entry
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: const InputDecoration(labelText: 'Latitude', isDense: true, border: OutlineInputBorder()),
                            style: PulseTextStyles.body,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lngController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: const InputDecoration(labelText: 'Longitude', isDense: true, border: OutlineInputBorder()),
                            style: PulseTextStyles.body,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final lat = double.tryParse(_latController.text.trim());
                            final lng = double.tryParse(_lngController.text.trim());
                            if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
                              setState(() => _officeLocation = LatLng(lat, lng));
                              _mapController.move(_officeLocation, 15);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid coordinates')));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: PulseColors.primary, foregroundColor: Colors.white),
                          child: const Text('SET'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Toggle to turn off geofencing globally (useful for remote teams)
                    SwitchListTile(
                      title: Text('Enable Geofencing restriction', style: PulseTextStyles.bodyBold),
                      subtitle: Text('Users must be within radius to punch in', style: PulseTextStyles.caption),
                      activeColor: PulseColors.success,
                      contentPadding: EdgeInsets.zero,
                      value: _geofenceEnabled,
                      onChanged: (val) {
                        setState(() => _geofenceEnabled = val);
                        _saveSettings(silent: true);
                      },
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
                    // MASTER SWITCH: Enable/Disable the entire Payroll module
                    SwitchListTile(
                      title: Text('Enable Payroll & Payslips', style: PulseTextStyles.bodyBold),
                      subtitle: Text('Generate and manage employee payslips', style: PulseTextStyles.caption),
                      activeColor: PulseColors.success,
                      contentPadding: EdgeInsets.zero,
                      value: _payrollEnabled,
                      onChanged: (val) {
                        setState(() => _payrollEnabled = val);
                        _saveSettings(silent: true);
                      },
                    ),
                    const Divider(height: 32),
                    // CAMERA AUTH: Enable/Disable selfie Requirement
                    SwitchListTile(
                      title: Text('Camera Authentication', style: PulseTextStyles.bodyBold),
                      subtitle: Text('Require a selfie for check-in and check-out', style: PulseTextStyles.caption),
                      activeColor: PulseColors.success,
                      contentPadding: EdgeInsets.zero,
                      value: _cameraAuthEnabled,
                      onChanged: (val) {
                        setState(() => _cameraAuthEnabled = val);
                        _saveSettings(silent: true);
                      },
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
          );

    if (widget.isTab) return content;

    return Scaffold(
      appBar: PulseAppBar(
        title: 'Company Settings',
        actions: [
          IconButton(
            icon: const Icon(Icons.beach_access),
            tooltip: 'Manage Holidays',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminHolidaysScreen())),
          ),
        ],
      ),
      body: content,
    );
  }

  void _showColorPickerDialog(String label, Color initialColor, Function(String) onPicked) {
    Color selected = initialColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pick $label Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor,
            onColorChanged: (c) => selected = c,
            enableAlpha: false,
            displayThumbColor: true,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          PulseButton(
            text: 'APPLY', 
            isSmall: true,
            onPressed: () {
              final hex = '#${selected.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
              onPicked(hex);
              Navigator.pop(context);
            }
          ),
        ],
      )
    );
  }

  void _showPaletteActionDialog(Color color) {
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use this color?'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 60, height: 60, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: PulseColors.border))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PulseButton(
                text: 'SET AS PRIMARY', 
                isSmall: true, 
                onPressed: () {
                  setState(() => _currentThemeColor = hex);
                  Navigator.pop(context);
                }
              ),
              const SizedBox(height: 8),
              PulseButton(
                text: 'SET AS SECONDARY', 
                isSmall: true,
                onPressed: () {
                  setState(() => _secondaryColor = hex);
                  Navigator.pop(context);
                }
              ),
            ],
          ),
        ],
      )
    );
  }

}

// --- Specialized Branding Widgets ---

class _LogoUploadWidget extends StatelessWidget {
  final String? logoUrl;
  final XFile? selectedLogo;
  final VoidCallback onPickLogo;

  const _LogoUploadWidget({
    required this.logoUrl,
    required this.selectedLogo,
    required this.onPickLogo,
  });

  @override
  Widget build(BuildContext context) {
    return PulseCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PulseColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.business_outlined, color: PulseColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Company Identity', style: PulseTextStyles.bodyBold),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: onPickLogo,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: PulseColors.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: PulseColors.border, width: 2),
                      boxShadow: PulseColors.premiumShadow,
                      image: selectedLogo != null
                          ? DecorationImage(image: FileImage(File(selectedLogo!.path)), fit: BoxFit.contain)
                          : (logoUrl != null
                              ? DecorationImage(image: CachedNetworkImageProvider(ApiService.getImageUrl(logoUrl!)), fit: BoxFit.contain)
                              : null),
                    ),
                    child: (selectedLogo == null && logoUrl == null)
                        ? Icon(Icons.add_a_photo_outlined, size: 40, color: PulseColors.textHint)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                PulseButton(
                  text: 'Upload New Logo',
                  icon: Icons.upload_rounded,
                  isSmall: true,
                  onPressed: onPickLogo,
                ),
                const SizedBox(height: 8),
                Text('Logo palette will be instantly applied to the app theme.', style: PulseTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandingPaletteWidget extends StatelessWidget {
  final String? currentThemeColor;
  final String? secondaryColor;
  final String? accentColor;
  final Function(String) onPrimaryPicked;
  final Function(String) onSecondaryPicked;
  final Function(String) onAccentPicked;
  final Function(String, Color, Function(String)) showColorPickerDialog;
  final Function(Color) showPaletteActionDialog;

  const _BrandingPaletteWidget({
    required this.currentThemeColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.onPrimaryPicked,
    required this.onSecondaryPicked,
    required this.onAccentPicked,
    required this.showColorPickerDialog,
    required this.showPaletteActionDialog,
  });

  @override
  Widget build(BuildContext context) {
    return PulseCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PulseColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.palette_outlined, color: PulseColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Visual Branding', style: PulseTextStyles.bodyBold),
            ],
          ),
          const SizedBox(height: 20),
          
          Text('Manual Overrides', style: PulseTextStyles.captionBold),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _colorSelectionItem(
                context,
                label: 'Primary',
                hexColor: currentThemeColor,
                onPicked: onPrimaryPicked,
              ),
              _colorSelectionItem(
                context,
                label: 'Secondary',
                hexColor: secondaryColor,
                onPicked: onSecondaryPicked,
              ),
              _colorSelectionItem(
                context,
                label: 'Accent',
                hexColor: accentColor,
                onPicked: onAccentPicked,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          Text('Smart Palette (from Logo)', style: PulseTextStyles.captionBold),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, child) {
              final branding = ref.watch(brandingProvider);
              if (branding.extractedPalette.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PulseColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PulseColors.border, style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: PulseColors.textHint),
                      const SizedBox(width: 8),
                      Text('Upload a logo to see suggested colors', style: PulseTextStyles.caption),
                    ],
                  ),
                );
              }
              return SizedBox(
                height: 54,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: branding.extractedPalette.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final color = branding.extractedPalette[index];
                    return GestureDetector(
                      onTap: () => showPaletteActionDialog(color),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: PulseColors.border, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.add, 
                            size: 16, 
                            color: color.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _colorSelectionItem(BuildContext context, {required String label, String? hexColor, required Function(String) onPicked}) {
    final color = hexColor != null ? Color(int.parse(hexColor.replaceAll('#', 'FF'), radix: 16)) : PulseColors.primary;
    return Column(
      children: [
        GestureDetector(
          onTap: () => showColorPickerDialog(label, color, onPicked),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            child: Icon(Icons.colorize, size: 24, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: PulseTextStyles.captionBold),
      ],
    );
  }
}
