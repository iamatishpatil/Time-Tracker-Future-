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

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
    _loadUserData();
    _getCurrentLocation();

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
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
    setState(() {
      _currentTime = DateFormat('hh:mm:ss a').format(now);
      _currentDate = DateFormat('EEEE, d MMMM y').format(now);
    });
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

  Future<void> _handleCheckOut() async {
    bool isInside = false;
    double distance = 0;
    try {
      final settings = await ApiService.getSettings();
      if (settings['geofenceEnabled'] == 0) {
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
      }
    } catch (_) {}

    if (!isInside) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('You are ${distance.toInt()}m away. Move closer to check out.'),
      ));
      return;
    }

    setState(() => _isLoading = true);

    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);

    if (photo == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selfie required for check-out')));
      setState(() => _isLoading = false);
      return;
    }

    try {
      await ApiService.checkOut(_user!['id'], lat: _currentPosition.latitude, long: _currentPosition.longitude, address: _currentAddress, photo: photo);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Checked Out Successfully!')));
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Session'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Session Status Card
            PulseCard(
              glowEffect: true,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: PulseColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
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
                          letterSpacing: 1.5,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_currentTime, style: PulseTextStyles.mono),
                  const SizedBox(height: 4),
                  Text(_currentDate, style: PulseTextStyles.caption),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Map
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
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
                              child: const Icon(Icons.location_on, color: PulseColors.error, size: 36),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: PulseColors.surface.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PulseColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: PulseColors.accent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _currentAddress,
                                style: PulseTextStyles.captionBold,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Checkout Button
            ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: _isLoading ? null : _handleCheckOut,
                child: Container(
                  width: double.infinity,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: PulseColors.error.withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.stop_circle_outlined, size: 36, color: Colors.white),
                              const SizedBox(width: 12),
                              Text('CHECK OUT',
                                  style: PulseTextStyles.button.copyWith(fontSize: 18)),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
