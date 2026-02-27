// --- 1. The Checkout Screen (Active Session) ---
// This screen is shown when the user has already checked in. It acts as a 
// "Stopwatch" that tracks their current shift.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../core/widgets/pulse_card.dart';
import '../services/api_service.dart';

import '../core/widgets/pulse_scaffold.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> with SingleTickerProviderStateMixin {
  String _currentTime = '';
  String _currentDate = '';
  late Timer _timer;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  LatLng _currentPosition = const LatLng(0, 0);
  String _currentAddress = 'Fetching location...';
  final MapController _mapController = MapController();

  // --- Animation ---
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation; // Makes the red button throb

  @override
  void initState() {
    super.initState();
    _updateTime();
    // Update the clock every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
    _loadUserData();
    _getCurrentLocation();

    // Setup the throb animation (same as Home Screen but for the red button)
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    // ANR Fix: Only call setState if the displayed strings actually changed
    // Prevents redundant rebuilds every second when nothing has visually changed
    final newTime = DateFormat('hh:mm:ss a').format(now);
    final newDate = DateFormat('EEEE, d MMMM y').format(now);
    if (mounted && (newTime != _currentTime || newDate != _currentDate)) {
      setState(() {
        _currentTime = newTime;
        _currentDate = newDate;
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = await ApiService.getStoredUser();
      if (user != null) {
        setState(() => _user = user);
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- GPS Tracking (Same logic as Home Screen) ---
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _mapController.move(_currentPosition, 15);
      });
      _getAddressFromLatLng(position.latitude, position.longitude);
    }
  }

  // Helper to turn coordinates into an address
  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (mounted) {
          setState(() {
            _currentAddress = '${place.name}, ${place.subLocality}, ${place.locality}';
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // --- The Check-Out Button Logic ---
  Future<void> _handleCheckOut() async {
    bool isInside = false;
    double distance = 0;

    // ANR Fix: Fetch settings ONCE and reuse for both geofence + camera checks
    Map<String, dynamic>? settings;
    try {
      settings = await ApiService.getSettings();
    } catch (_) {}

    try {
      // 1. Verify Geofence (Can't check out from outside!)
      if (settings == null || settings['geofenceEnabled'] == 0) {
        isInside = true;
      } else if (settings['officeLat'] != null) {
        final double officeLat = (settings['officeLat'] as num).toDouble();
        final double officeLong = (settings['officeLong'] as num).toDouble();
        final double officeRadius = (settings['officeRadiusMeters'] as num?)?.toDouble() ?? 100.0;
        
        distance = Geolocator.distanceBetween(
          _currentPosition.latitude, _currentPosition.longitude,
          officeLat, officeLong,
        );
        isInside = distance <= officeRadius;
      } else {
        isInside = true; // No office location set, allow checkout
      }
    } catch (_) {}

    if (!isInside) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('You are ${distance.toInt()}m away. Move closer to check out.'),
        backgroundColor: PulseColors.error,
      ));
      return;
    }

    setState(() => _isLoading = true);

    // 2. Take a Goodbye Selfie! (reuse settings fetched above — no second API call)
    XFile? photo;
    if (settings != null && settings['cameraAuthEnabled'] != 0) {
      final ImagePicker picker = ImagePicker();
      photo = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);

      if (photo == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selfie required for check-out'), backgroundColor: PulseColors.error));
        setState(() => _isLoading = false);
        return;
      }
    }


    try {
      // 3. Inform the server that the shift has ended
      await ApiService.checkOut(_user!['id'], lat: _currentPosition.latitude, long: _currentPosition.longitude, address: _currentAddress, photo: photo);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ Checked Out Successfully!'),
        backgroundColor: PulseColors.success,
      ));
      
      // 4. Send them back home (where the "CHECK IN" button will be visible again)
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: PulseColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulseScaffold(
      title: 'Active Session',
      useBrandedBackground: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. Status Indicator ---
            PulseCard(
              glowEffect: true,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: PulseColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: PulseColors.success.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: PulseColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('SESSION ACTIVE', style: PulseTextStyles.captionBold.copyWith(
                          color: PulseColors.success,
                          letterSpacing: 2.0,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(_currentTime, style: PulseTextStyles.h1.copyWith(
                    color: PulseColors.brandPrimary,
                    fontSize: 42,
                    letterSpacing: -1,
                  )),
                  const SizedBox(height: 8),
                  Text(_currentDate, style: PulseTextStyles.body.copyWith(
                    color: PulseColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- 2. Live Map ---
            PulseCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(
                      height: 180,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(initialCenter: _currentPosition, initialZoom: 15.0),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.timetracker.frontend',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _currentPosition,
                                    width: 40,
                                    height: 40,
                                    child: Icon(Icons.location_on, color: PulseColors.brandPrimary, size: 36),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: FloatingActionButton.small(
                              onPressed: _getCurrentLocation,
                              backgroundColor: PulseColors.surface,
                              child: Icon(Icons.my_location, color: PulseColors.brandPrimary, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: PulseColors.brandLight.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.location_on, size: 16, color: PulseColors.brandPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current Location', style: PulseTextStyles.captionBold),
                              Text(
                                _currentAddress,
                                style: PulseTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // --- 3. The Bespoke Checkout Button ---
            ScaleTransition(
              scale: _pulseAnimation,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isLoading ? null : _handleCheckOut,
                    child: Container(
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: PulseColors.brandGradient,
                        boxShadow: [
                          BoxShadow(
                            color: PulseColors.brandPrimary.withOpacity(0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.logout_rounded, size: 28, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Text('CHECK OUT NOW',
                                      style: PulseTextStyles.button.copyWith(
                                        fontSize: 18, 
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      )),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ensure you are within the office vicinity',
                    textAlign: TextAlign.center,
                    style: PulseTextStyles.caption.copyWith(color: PulseColors.textHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
