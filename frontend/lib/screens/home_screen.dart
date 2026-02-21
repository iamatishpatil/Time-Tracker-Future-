import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../core/widgets/pulse_card.dart';
import '../core/widgets/pulse_shimmer.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late String _timeString;
  late String _dateString;
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isCheckedIn = false;
  String _currentAddress = "Fetching location...";
  LatLng _currentPosition = const LatLng(0, 0);
  final MapController _mapController = MapController();
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  String _todayHours = "0.0";
  String _monthHours = "0.0";
  String _attendanceRate = "0%";
  Map<String, dynamic> _leaveBalance = {'total': 0, 'used': 0, 'remaining': 0};

  bool _isInsideRadius = false;
  Map<String, dynamic>? _settings;

  String? _todayHoliday;
  String? _holidayType;
  List<dynamic> _upcomingHolidays = [];

  @override
  void initState() {
    super.initState();
    _timeString = _formatDateTime(DateTime.now());
    _dateString = _formatDate(DateTime.now());
    Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());

    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _initializeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadUser();
    await _getCurrentLocation();
    await _loadStats();
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getStoredUser();
    if (mounted) setState(() => _user = user);
    if (user != null) {
      final isCheckedIn = await ApiService.getCheckInStatus(user['id']);
      if (mounted) setState(() => _isCheckedIn = isCheckedIn);
    }
  }

  Future<void> _loadStats() async {
    if (_user == null) return;
    try {
      final history = await ApiService.getAttendance(_user!['id']);
      final leave = await ApiService.getLeaveBalance(_user!['id']);
      final holidays = await ApiService.getHolidays();

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      String? holidayName;
      String? holidayType;
      List<dynamic> upcoming = [];

      for (var h in holidays) {
        if (h['date'] == todayStr) {
          holidayName = h['name'];
          holidayType = h['type'];
          if (h['duration'] == 'Half Day') holidayName = '$holidayName (½ Day)';
        }
        final hDate = DateTime.parse(h['date']);
        if (hDate.isAfter(now)) {
          upcoming.add(h);
        }
      }
      upcoming.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
      if (upcoming.length > 5) upcoming = upcoming.sublist(0, 5);

      if (mounted) {
        setState(() {
          _todayHoliday = holidayName;
          _holidayType = holidayType;
          _upcomingHolidays = upcoming;
        });
      }

      double totalHours = 0;
      double todayHours = 0;
      int presentDays = 0;
      for (var record in history) {
        final checkIn = DateTime.parse(record['checkInTime']);
        if (checkIn.day == now.day && checkIn.month == now.month && checkIn.year == now.year) {
          if (record['checkOutTime'] != null) {
            final checkOut = DateTime.parse(record['checkOutTime']);
            todayHours += checkOut.difference(checkIn).inMinutes / 60.0;
          } else {
            todayHours += now.difference(checkIn).inMinutes / 60.0;
          }
        }
        if (checkIn.month == now.month && checkIn.year == now.year) {
          presentDays++;
          if (record['checkOutTime'] != null) {
            final checkOut = DateTime.parse(record['checkOutTime']);
            totalHours += checkOut.difference(checkIn).inMinutes / 60.0;
          }
        }
      }

      double totalWorkingDaysCount = 0;
      final Set<String> weekOffDays = (_user?['weekOffs'] ?? 'Sunday').split(',').map((s) => s.trim()).toSet();

      try {
        final holidays = await ApiService.getHolidays();
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        for (int d = 1; d <= daysInMonth; d++) {
          final date = DateTime(now.year, now.month, d);
          final dayName = DateFormat('EEEE').format(date);
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final holiday = holidays.firstWhere((h) => h['date'] == dateStr, orElse: () => null);
          if (!weekOffDays.contains(dayName)) {
            if (holiday == null || holiday['type'] == 'Optional') {
              totalWorkingDaysCount += 1.0;
            } else if (holiday['duration'] == 'Half Day') {
              totalWorkingDaysCount += 0.5;
            }
          }
        }
      } catch (_) {
        totalWorkingDaysCount = 22.0;
      }

      if (totalWorkingDaysCount == 0) totalWorkingDaysCount = 1.0;
      double rate = (presentDays / totalWorkingDaysCount) * 100;

      if (mounted) {
        setState(() {
          _todayHours = todayHours.toStringAsFixed(1);
          _monthHours = totalHours.toStringAsFixed(1);
          _attendanceRate = "${rate.toInt()}%";
          _leaveBalance = leave;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _getTime() {
    final DateTime now = DateTime.now();
    if (mounted) {
      setState(() {
        _timeString = _formatDateTime(now);
        _dateString = _formatDate(now);
      });
    }
  }

  String _formatDateTime(DateTime dateTime) => DateFormat('hh:mm:ss a').format(dateTime);
  String _formatDate(DateTime dateTime) => DateFormat('EEEE, MMMM d, y').format(dateTime);

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

    final position = await Geolocator.getCurrentPosition();

    bool isInside = false;
    try {
      _settings ??= await ApiService.getSettings();
      if (_settings != null && _settings!['geofenceEnabled'] == 0) {
        isInside = true;
      } else if (_settings != null && _settings!['officeLat'] != null) {
        final double officeLat = (_settings!['officeLat'] as num).toDouble();
        final double officeLong = (_settings!['officeLong'] as num).toDouble();
        final double officeRadius = (_settings!['officeRadiusMeters'] as num?)?.toDouble() ?? 100.0;
        
        double distance = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          officeLat, officeLong,
        );
        isInside = distance <= officeRadius;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isInsideRadius = isInside;
        _mapController.move(_currentPosition, 15.0);
      });
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress = "${place.street}, ${place.subLocality}, ${place.locality}";
        });
      }
    } catch (_) {}
  }

  Future<void> _handleCheckIn() async {
    if (!_isInsideRadius) {
      double distance = 0;
      if (_settings != null && _settings!['officeLat'] != null) {
        final double officeLat = (_settings!['officeLat'] as num).toDouble();
        final double officeLong = (_settings!['officeLong'] as num).toDouble();
        
        distance = Geolocator.distanceBetween(
          _currentPosition.latitude, _currentPosition.longitude,
          officeLat, officeLong,
        );
      }
      final double officeRadius = (_settings?['officeRadiusMeters'] as num?)?.toDouble() ?? 100.0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('You are ${distance.toInt()}m away. Move within ${officeRadius.toInt()}m of office.'),
      ));
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.checkIn(
        _user!['id'],
        lat: _currentPosition.latitude,
        long: _currentPosition.longitude,
        address: _currentAddress,
        photo: image,
      );
      if (!mounted) return;

      setState(() => _isCheckedIn = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Checked In Successfully!')));
      Navigator.pushNamed(context, '/checkout');
      _loadStats();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _user == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: PulseShimmer.list(count: 4, itemHeight: 100),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Row
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: PulseColors.surfaceVariant,
                backgroundImage: _settings?['companyLogo'] != null
                    ? NetworkImage(ApiService.getImageUrl(_settings!['companyLogo']))
                    : (_user?['profilePicture'] != null 
                        ? NetworkImage(ApiService.getImageUrl(_user!['profilePicture'])) 
                        : null),
                child: (_settings?['companyLogo'] == null && _user?['profilePicture'] == null)
                    ? const Icon(Icons.business, size: 24, color: PulseColors.textHint)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: PulseTextStyles.caption),
                    Text(
                      _user?['fullName'] ?? 'User',
                      style: PulseTextStyles.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (_user?['shiftName'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: PulseColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 10, color: PulseColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              '${_user!['shiftName']} (${_user!['shiftStart']} - ${_user!['shiftEnd']})',
                              style: PulseTextStyles.captionBold.copyWith(
                                fontSize: 10,
                                color: PulseColors.accent,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: PulseColors.textHint.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'No Shift Assigned',
                          style: PulseTextStyles.caption.copyWith(fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
              // Geofence Badge
              if (_settings == null || _settings!['geofenceEnabled'] != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_isInsideRadius ? PulseColors.success : PulseColors.error).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_isInsideRadius ? PulseColors.success : PulseColors.error).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isInsideRadius ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: _isInsideRadius ? PulseColors.success : PulseColors.error,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isInsideRadius ? 'In Office' : 'Outside',
                        style: PulseTextStyles.captionBold.copyWith(
                          color: _isInsideRadius ? PulseColors.success : PulseColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Holiday Banner
          if (_todayHoliday != null) ...[
            PulseCard(
              color: _holidayType == 'Public'
                  ? PulseColors.success.withOpacity(0.1)
                  : PulseColors.accent.withOpacity(0.1),
              borderColor: _holidayType == 'Public'
                  ? PulseColors.success.withOpacity(0.3)
                  : PulseColors.accent.withOpacity(0.3),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Today is $_todayHoliday',
                      style: PulseTextStyles.bodyBold.copyWith(
                        color: _holidayType == 'Public' ? PulseColors.success : PulseColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Clock Card
          PulseCard(
            glowEffect: true,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    style: PulseTextStyles.mono.copyWith(fontSize: 48, letterSpacing: -1),
                    children: [
                      TextSpan(
                        text: _timeString.split(':')[0],
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      TextSpan(
                        text: ':',
                        style: TextStyle(color: PulseColors.primary, fontWeight: FontWeight.w300),
                      ),
                      TextSpan(
                        text: _timeString.split(':')[1],
                        style: const TextStyle(fontWeight: FontWeight.w400, color: PulseColors.textSecondary),
                      ),
                      TextSpan(
                        text: ':',
                        style: TextStyle(color: PulseColors.primary, fontWeight: FontWeight.w300),
                      ),
                      TextSpan(
                        text: _timeString.split(':')[2].split(' ')[0],
                        style: const TextStyle(fontWeight: FontWeight.w200, color: PulseColors.textHint, fontSize: 32),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: _timeString.split(' ')[1],
                        style: PulseTextStyles.captionBold.copyWith(color: PulseColors.primary, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: PulseColors.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _dateString.toUpperCase(),
                    style: PulseTextStyles.captionBold.copyWith(
                      letterSpacing: 2,
                      fontSize: 10,
                      color: PulseColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats Row
          Row(
            children: [
              Expanded(child: _statCard('Today', '$_todayHours hrs', PulseColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Monthly', '$_monthHours hrs', PulseColors.accent)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Rate', _attendanceRate, PulseColors.success)),
            ],
          ),
          const SizedBox(height: 16),

          // Leave Balance Mini
          PulseCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PulseColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.beach_access_rounded, color: PulseColors.warning, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Leave Balance', style: PulseTextStyles.captionBold),
                      const SizedBox(height: 2),
                      Text(
                        '${_leaveBalance['remaining']} remaining of ${_leaveBalance['total']}',
                        style: PulseTextStyles.body,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_leaveBalance['used']}',
                  style: PulseTextStyles.h3.copyWith(color: PulseColors.warning),
                ),
                Text(' used', style: PulseTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Upcoming Holidays
          if (_upcomingHolidays.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Upcoming Holidays', style: PulseTextStyles.bodyBold),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/user-holidays'),
                  child: Text('View All', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.primaryLight)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _upcomingHolidays.length,
                itemBuilder: (context, index) {
                  final holiday = _upcomingHolidays[index];
                  final isPublic = holiday['type'] == 'Public';
                  return Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PulseColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PulseColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          holiday['name'],
                          style: PulseTextStyles.bodyBold.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, y').format(DateTime.parse(holiday['date'])),
                          style: PulseTextStyles.caption,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPublic ? PulseColors.success.withOpacity(0.2) : PulseColors.warning.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            holiday['duration'] == 'Half Day' ? 'Half Day' : holiday['type'],
                            style: PulseTextStyles.captionBold.copyWith(
                              color: isPublic ? PulseColors.success : PulseColors.warning,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Map
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 160,
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
                      if (_settings != null && _settings!['officeLat'] != null) ...[
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: LatLng(
                                (_settings!['officeLat'] as num).toDouble(),
                                (_settings!['officeLong'] as num).toDouble(),
                              ),
                              color: PulseColors.primary.withOpacity(0.2),
                              borderStrokeWidth: 2,
                              borderColor: PulseColors.primary,
                              radius: (_settings!['officeRadiusMeters'] as num?)?.toDouble() ?? 100.0,
                              useRadiusInMeter: true,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                (_settings!['officeLat'] as num).toDouble(),
                                (_settings!['officeLong'] as num).toDouble(),
                              ),
                              width: 30,
                              height: 30,
                              child: const Icon(Icons.business, color: PulseColors.accent, size: 28),
                            ),
                          ],
                        ),
                      ],
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPosition,
                            width: 40,
                            height: 40,
                            child: Icon(Icons.person_pin_circle, color: PulseColors.primary, size: 36),
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
          const SizedBox(height: 24),

          // Check In / Checkout Button
          if (!_isCheckedIn)
            ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: (_isLoading || !_isInsideRadius) ? null : _handleCheckIn,
                child: Container(
                  width: double.infinity,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: _isInsideRadius ? PulseColors.primaryGradient : null,
                    color: !_isInsideRadius ? PulseColors.surfaceVariant : null,
                    boxShadow: [
                      if (_isInsideRadius)
                        BoxShadow(
                          color: PulseColors.primary.withOpacity(0.4),
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
                              Icon(Icons.touch_app_rounded, size: 36, color: _isInsideRadius ? Colors.white : PulseColors.textHint),
                              const SizedBox(width: 12),
                              Text(
                                _isInsideRadius ? 'CHECK IN' : 'OUTSIDE RADIUS', 
                                style: PulseTextStyles.button.copyWith(
                                  fontSize: 18, 
                                  color: _isInsideRadius ? Colors.white : PulseColors.textHint,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/checkout'),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Go to Checkout'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return PulseCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Text(value, style: PulseTextStyles.h3.copyWith(color: color, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: PulseTextStyles.caption),
        ],
      ),
    );
  }
}
