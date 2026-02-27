// --- 7. The Control Tower (Settings) ---
// This is the most powerful screen for the Admin. It controls the "Rules of the Game":
// 1. Where the office is (Geofencing)
// 2. What the app looks like (Dynamic Branding)
// 3. Which features are active (Payroll toggle)

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
        setState(() => _officeLocation = LatLng(position.latitude, position.longitude));
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
      });
      
      // Update local branding provider to reflect changes immediately
      if (_currentThemeColor != null) {
        final color = Color(int.parse(_currentThemeColor!.replaceAll('#', 'FF'), radix: 16));
        await ref.read(brandingProvider.notifier).updateBranding(_currentLogoUrl, color, companyName: _nameController.text.trim());
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
          
      final hexColor = '#${dominantColor.value.toRadixString(16).substring(2).toUpperCase()}';

      final response = await ApiService.updateBranding(logo: image, themeColor: hexColor);
      
      // Real-time branding update via provider (now asynchronous for full extraction)
      await ref.read(brandingProvider.notifier).updateBranding(
        response['logo'],
        dominantColor,
        companyName: _nameController.text.trim(),
      );
      
      setState(() {
        _currentThemeColor = hexColor;
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

                // Branding
                PulseCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.palette, color: PulseColors.accent, size: 20),
                      const SizedBox(width: 8),
                      Text('App Branding & Theme', style: PulseTextStyles.bodyBold),
                    ]),
                    const SizedBox(height: 10),
                    Text('Customize your organization\'s look. Pick a brand color or upload your company logo to automatically extract its palette.', style: PulseTextStyles.caption),
                    const SizedBox(height: 16),
                    
                    // Color Picker Grid
                    Text('Select Brand Color', style: PulseTextStyles.captionBold),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        // Pulse Premium Palette
                        _brandColorCircle(const Color(0xFF7C4DFF), 'Indigo'),
                        _brandColorCircle(const Color(0xFF00B8D4), 'Teal'),
                        _brandColorCircle(const Color(0xFF00C853), 'Green'),
                        _brandColorCircle(const Color(0xFFFF3D00), 'Orange'),
                        _brandColorCircle(const Color(0xFFE91E63), 'Rose'),
                        _brandColorCircle(const Color(0xFF2196F3), 'Blue'),
                        _brandColorCircle(const Color(0xFF000000), 'Rich Black'),
                        _brandColorCircle(const Color(0xFFFFD600), 'Amber'),
                        
                        // Custom Color Button
                        GestureDetector(
                          onTap: _showCustomColorDialog,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: PulseColors.border, width: 2),
                              gradient: const SweepGradient(
                                colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.red],
                              ),
                            ),
                            child: const Icon(Icons.colorize, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    Text('Company Logo', style: PulseTextStyles.captionBold),
                    const SizedBox(height: 10),
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
                              ? Icon(Icons.business, size: 30, color: PulseColors.textHint)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PulseButton(
                            text: 'Change Logo',
                            icon: Icons.upload,
                            isSmall: true,
                            onPressed: _pickAndUploadLogo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Brand Palette', style: PulseTextStyles.captionBold),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _colorCircle(PulseColors.brandPrimary, 'PR'),
                            _colorCircle(PulseColors.brandVibrant, 'VB'),
                            _colorCircle(PulseColors.brandMuted, 'MT'),
                            _colorCircle(PulseColors.brandLight, 'LT'),
                            _colorCircle(PulseColors.primaryDark, 'DK'),
                          ],
                        ),
                      ],
                    ),
                  ]),
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
                            onTap: (tapPosition, point) => setState(() => _officeLocation = point),
                          ),
                          children: [
                            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.timetracker.frontend'),
                            // This circle shows the "Allowed Area" for check-ins
                            CircleLayer(circles: [
                              CircleMarker(point: _officeLocation, color: PulseColors.primary.withOpacity(0.25), borderStrokeWidth: 2, borderColor: PulseColors.primary, radius: _radius, useRadiusInMeter: true),
                            ]),
                            MarkerLayer(markers: [
                              Marker(point: _officeLocation, width: 40, height: 40, child: Icon(Icons.location_on, color: PulseColors.error, size: 40)),
                            ]),
                          ],
                        ),
                      ),
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

  Widget _colorCircle(Color color, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 12),
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
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _brandColorCircle(Color color, String label) {
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    final isSelected = _currentThemeColor == hex;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentThemeColor = hex;
        });
        // Real-time preview for admin
        PulseColors.setCompanyBrandColor(color);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent, 
            width: 2.5
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)
          ] : [],
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }

  void _showCustomColorDialog() {
    final controller = TextEditingController(text: _currentThemeColor ?? '#7C4DFF');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Brand Color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter Hex Code (e.g. #FF5722)'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '#RRGGBB',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          PulseButton(
            text: 'APPLY', 
            isSmall: true,
            onPressed: () {
              String hex = controller.text.trim().toUpperCase();
              if (!hex.startsWith('#')) hex = '#$hex';
              if (hex.length != 7) return;
              
              try {
                final color = Color(int.parse(hex.replaceAll('#', 'FF'), radix: 16));
                setState(() {
                  _currentThemeColor = hex;
                });
                PulseColors.setCompanyBrandColor(color);
                Navigator.pop(context);
              } catch (_) {}
            }
          ),
        ],
      )
    );
  }
}
