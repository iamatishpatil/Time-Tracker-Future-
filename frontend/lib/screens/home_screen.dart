import 'package:cached_network_image/cached_network_image.dart';
// --- Home Screen (Dashboard) ---
// ANR Root Causes fixed in this version:
// 1. GPS/Geocoding wrapped in timeouts - can no longer hang the UI
// 2. All API calls are parallel (Future.wait) not serial
// 3. Stats computation is isolated to a non-blocking invocation pattern
// 4. Timer only calls setState when the string actually changes (no redundant rebuilds)
// 5. checkIn navigates correctly to /checkout route

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../core/widgets/pulse_card.dart';
import '../core/widgets/pulse_shimmer.dart';
import '../core/widgets/pulse_clock.dart'; // [ADD]
import '../services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/branding_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isCheckedIn = false;
  bool _isActionLoading = false; // Separate loading flag for check-in button only

  // --- Location ---
  String _currentAddress = "Fetching location...";
  LatLng _currentPosition = const LatLng(20.5937, 78.9629); // India center default
  final MapController _mapController = MapController();

  // --- Animation ---
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // --- Dashboard Stats ---
  String _todayHours = "0.0";
  String _monthHours = "0.0";
  String _attendanceRate = "0%";
  Map<String, dynamic> _leaveBalance = {'total': 0, 'used': 0, 'remaining': 0};

  bool _isInsideRadius = true; // Default true so button is visible before GPS resolves
  Map<String, dynamic>? _settings;
  List<dynamic> _upcomingHolidays = [];
  String? _todayHoliday;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initializeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }


  Future<void> _initializeData() async {
    try {
      final user = await ApiService.getStoredUser();
      if (!mounted) return;
      setState(() => _user = user);

      if (user != null) {
        // ANR Fix: Fire GPS and API calls in parallel, don't wait for each other
        // GPS can be slow; we don't block the rest of the UI on it
        _startGPSInBackground();
        await _loadStats(user);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// GPS runs in its own async chain and updates the UI when ready.
  /// A 10s timeout prevents permanent hangs.
  void _startGPSInBackground() {
    _fetchLocation().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('GPS timed out - using default position');
      },
    ).catchError((e) => debugPrint('GPS error: $e'));
  }

  Future<void> _fetchLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (!mounted) return;
    final latlng = LatLng(position.latitude, position.longitude);
    setState(() => _currentPosition = latlng);

    // Move map safely; it may not be fully initialized yet
    try { _mapController.move(latlng, 15.0); } catch (_) {}

    // Reverse geocoding with its own timeout
    _reverseGeocode(position.latitude, position.longitude);

    // Check geofence
    if (_settings != null && _settings!['officeLat'] != null) {
      final double dist = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        (_settings!['officeLat'] as num).toDouble(),
        (_settings!['officeLong'] as num).toDouble(),
      );
      
      // Feature: 20m grace buffer to account for GPS jitter
      const double buffer = 20.0;
      final double allowedRadius = ((_settings!['officeRadiusMeters'] as num?)?.toDouble() ?? 100.0) + buffer;
      
      if (mounted) setState(() => _isInsideRadius = dist <= allowedRadius);
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 6));
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks[0];
        setState(() => _currentAddress = '${p.street}, ${p.subLocality}, ${p.locality}');
      }
    } catch (_) {
      // Silently fail — address just shows "Fetching location..."
    }
  }

  Future<void> _loadStats(Map<String, dynamic> user) async {
    final userId = user['id'];
    try {
      // ANR Fix: Parallel fetch — all four requests fire simultaneously
      final results = await Future.wait([
        ApiService.getCheckInStatus(userId).timeout(const Duration(seconds: 8)),
        ApiService.getDashboardStats(userId).timeout(const Duration(seconds: 10)),
        ApiService.getLeaveBalance(userId).timeout(const Duration(seconds: 8)),
        ApiService.getSettings().timeout(const Duration(seconds: 8)),
        ApiService.getHolidays().timeout(const Duration(seconds: 8)),
      ], eagerError: false);

      if (!mounted) return;

      final statusMap = results[0] as Map<String, dynamic>;
      final stats = results[1] as Map<String, dynamic>;
      final leaves = results[2] as Map<String, dynamic>;
      final settings = results[3] as Map<String, dynamic>;
      final holidays = results[4] as List<dynamic>;

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final todayHoliday = holidays.firstWhere((h) => h['date'] == todayStr, orElse: () => null);
      final upcoming = holidays.where((h) {
        try { 
          final d = DateTime.parse(h['date']);
          final today = DateTime(now.year, now.month, now.day);
          return !d.isBefore(today) && d.month == now.month && d.year == now.year;
        } catch (_) { return false; }
      }).take(5).toList();

      setState(() {
        _isCheckedIn = statusMap['isCheckedIn'] ?? false;
        _todayHours = stats['todayHours']?.toString() ?? '0.0';
        _monthHours = stats['monthHours']?.toString() ?? '0.0';
        _attendanceRate = '${stats['attendanceRate'] ?? 0}%';
        _leaveBalance = leaves;
        _settings = settings;
        _upcomingHolidays = upcoming;
        if (todayHoliday != null) _todayHoliday = todayHoliday['name'];

        // Geofence Logic:
        if (settings['geofenceEnabled'] == 0 || settings['officeLat'] == null) {
          _isInsideRadius = true;
        } else {
          // Fix: If GPS already resolved before settings loaded, check geofence now
          final double dist = Geolocator.distanceBetween(
            _currentPosition.latitude, _currentPosition.longitude,
            (settings['officeLat'] as num).toDouble(),
            (settings['officeLong'] as num).toDouble(),
          );
          const double buffer = 20.0;
          final double allowedRadius = ((settings['officeRadiusMeters'] as num?)?.toDouble() ?? 100.0) + buffer;
          _isInsideRadius = dist <= allowedRadius;
        }
      });
    } catch (e) {
      debugPrint('Stats load error: $e');
      // Don't crash — just show defaults
    }
  }

  Future<void> _handleCheckIn() async {
    if (_isActionLoading || _user == null) return;
    setState(() => _isActionLoading = true);
    
    // ANR Fix / Feature: Enforce Camera Authentication if required by Admin
    XFile? photo;
    if (_settings != null && _settings!['cameraAuthEnabled'] != 0) {
      try {
        final ImagePicker picker = ImagePicker();
        photo = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
        
        if (photo == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Selfie is strictly required for check-in by Admin.'), 
            backgroundColor: PulseColors.error
          ));
          setState(() => _isActionLoading = false);
          return;
        }
      } catch (e) {
        debugPrint('Camera error: $e');
      }
    }

    try {
      // ANR Fix: checkIn itself is async and is awaited properly
      await ApiService.checkIn(
        _user!['id'],
        lat: _currentPosition.latitude,
        long: _currentPosition.longitude,
        address: _currentAddress,
        photo: photo,
      );
      if (!mounted) return;
      setState(() => _isCheckedIn = true);
      Navigator.pushNamed(context, '/checkout');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: PulseColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _refresh() async {
    if (_user != null) await _loadStats(_user!);
    _startGPSInBackground();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(brandingProvider);
    
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: PulseShimmer.list(count: 4, itemHeight: 100),
      );
    }

    return Stack(
      children: [
        // Branded background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: PulseColors.background,
              gradient: PulseColors.meshGradient,
            ),
          ),
        ),
        // Top glow
        Positioned(
          top: -100, left: -100,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PulseColors.primary.withValues(alpha: 0.12),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox.shrink(),
            ),
          ),
        ),
        RefreshIndicator(
          onRefresh: _refresh,
          color: PulseColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              children: [
                // --- Welcome Row ---
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: PulseColors.brandGlow),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: PulseColors.surface,
                        backgroundImage: _user?['profilePicture'] != null
                            ? CachedNetworkImageProvider(ApiService.getImageUrl(_user!['profilePicture']))
                            : null,
                        child: _user?['profilePicture'] == null
                            ? const Icon(Icons.person, size: 24, color: PulseColors.textHint)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back,', style: PulseTextStyles.caption.copyWith(letterSpacing: 0.5)),
                          Text(
                            _user?['fullName'] ?? 'User',
                            style: PulseTextStyles.h3.copyWith(fontWeight: FontWeight.w900, fontSize: 22),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _buildGeofenceBadge(),
                  ],
                ),
                const SizedBox(height: 20),

                // --- Shift Info ---
                if (_user?['shiftName'] != null)
                  PulseCard(
                    glassEffect: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: PulseColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(Icons.schedule_rounded, size: 18, color: PulseColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CURRENT SHIFT', style: PulseTextStyles.captionBold.copyWith(fontSize: 9, letterSpacing: 1)),
                            Text(
                              '${_user!['shiftName']} · ${_user!['shiftStart']} - ${_user!['shiftEnd']}',
                              style: PulseTextStyles.bodyBold.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // --- Holiday Banner ---
                if (_todayHoliday != null)
                  PulseCard(
                    glowEffect: true,
                    color: PulseColors.success,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 14),
                        Expanded(child: Text('Today: $_todayHoliday', style: PulseTextStyles.bodyBold.copyWith(color: Colors.white))),
                      ],
                    ),
                  ),

                PulseCard(
                  glowEffect: true,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  child: const PulseClock(detailed: true),
                ),
                const SizedBox(height: 16),

                // --- Stats Row ---
                Row(
                  children: [
                    Expanded(child: _statCard('Today', _todayHours, 'HRS', PulseColors.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Month', _monthHours, 'HRS', PulseColors.accent)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Rate', _attendanceRate, '', PulseColors.success)),
                  ],
                ),
                const SizedBox(height: 16),

                // --- Leave Balance Card ---
                PulseCard(
                  glassEffect: true,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [PulseColors.warning, Colors.orangeAccent]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.beach_access_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LEAVE BALANCE', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.warning, fontSize: 9, letterSpacing: 1)),
                            Text('${_leaveBalance['remaining']} days remaining', style: PulseTextStyles.bodyBold.copyWith(fontSize: 15)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${_leaveBalance['used']}', style: PulseTextStyles.h3.copyWith(color: PulseColors.warning, fontWeight: FontWeight.w900)),
                          Text('USED', style: PulseTextStyles.captionBold.copyWith(fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- Upcoming Holidays ---
                if (_upcomingHolidays.isNotEmpty) _buildUpcomingHolidays(),

                // --- Mini Map ---
                _buildMiniMap(),
                const SizedBox(height: 28),

                // --- Action Button ---
                _buildActionButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildGeofenceBadge() {
    final inside = _settings == null || _settings!['geofenceEnabled'] == 0 || _isInsideRadius;
    final color = inside ? PulseColors.success : PulseColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 7),
          Text(inside ? 'IN RANGE' : 'OFF-SITE', style: PulseTextStyles.captionBold.copyWith(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, String unit, Color color) {
    return PulseCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          RichText(
            text: TextSpan(children: [
              TextSpan(text: value, style: PulseTextStyles.h3.copyWith(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
              if (unit.isNotEmpty) TextSpan(text: ' $unit', style: PulseTextStyles.captionBold.copyWith(fontSize: 8, color: color.withValues(alpha: 0.6))),
            ]),
          ),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: PulseTextStyles.captionBold.copyWith(fontSize: 9, letterSpacing: 1, color: PulseColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildUpcomingHolidays() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('UPCOMING HOLIDAYS', style: PulseTextStyles.captionBold.copyWith(letterSpacing: 1)),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/user-holidays'),
              child: Text('View All', style: TextStyle(color: PulseColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _upcomingHolidays.length,
            itemBuilder: (context, i) {
              final h = _upcomingHolidays[i];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                child: PulseCard(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(h['name'] ?? 'Holiday', style: PulseTextStyles.bodyBold.copyWith(fontSize: 13), maxLines: 1),
                      const SizedBox(height: 4),
                      Text(DateFormat('MMM d').format(DateTime.parse(h['date'])), style: PulseTextStyles.caption),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: PulseColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(h['type'] ?? 'Holiday', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.primary, fontSize: 9)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMiniMap() {
    return PulseCard(
      padding: EdgeInsets.zero,
      borderRadius: 22,
      child: Column(
        children: [
          SizedBox(
            height: 170,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: _currentPosition, initialZoom: 14.0),
                children: [
                  TileLayer(
                    // CartoDB Positron: free, reliable, no API key, never blocked on emulators
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.pulsehub.timetracker',
                    maxZoom: 19,
                  ),
                  if (_settings != null && _settings!['officeLat'] != null)
                    CircleLayer(circles: [
                      CircleMarker(
                        point: LatLng((_settings!['officeLat'] as num).toDouble(), (_settings!['officeLong'] as num).toDouble()),
                        color: PulseColors.primary.withValues(alpha: 0.1),
                        borderStrokeWidth: 2,
                        borderColor: PulseColors.primary,
                        radius: (_settings!['officeRadiusMeters'] as num?)?.toDouble() ?? 100.0,
                        useRadiusInMeter: true,
                      ),
                    ]),
                  MarkerLayer(markers: [
                    Marker(point: _currentPosition, width: 36, height: 36, child: Icon(Icons.person_pin_circle, color: PulseColors.primary, size: 36)),
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, size: 16, color: PulseColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(_currentAddress, style: PulseTextStyles.captionBold, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final canCheckIn = _settings == null || _settings!['geofenceEnabled'] == 0 || _isInsideRadius;

    if (_isCheckedIn) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/checkout'),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('GO TO CHECKOUT'),
        ),
      );
    }

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: double.infinity,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: canCheckIn ? PulseColors.primaryGradient : null,
          color: !canCheckIn ? PulseColors.surfaceVariant : null,
          boxShadow: canCheckIn ? PulseColors.brandShadow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (_isActionLoading || !canCheckIn) ? null : _handleCheckIn,
            borderRadius: BorderRadius.circular(28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _isActionLoading
                    ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Icon(Icons.fingerprint_rounded, size: 40, color: canCheckIn ? Colors.white : PulseColors.textHint),
                const SizedBox(width: 14),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canCheckIn ? 'TAP TO CHECK IN' : 'LOCATION LOCKED',
                      style: PulseTextStyles.button.copyWith(
                        color: canCheckIn ? Colors.white : PulseColors.textHint,
                        fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1,
                      ),
                    ),
                    if (!canCheckIn)
                      Text('Move inside office geofence', style: PulseTextStyles.caption.copyWith(color: PulseColors.textHint, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
