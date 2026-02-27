// --- 1. The Home Screen (Dashboard) ---
// This is the first thing a user sees. It has the clock, the big "CHECK IN" 
// button, and a mini-map to show where they are.

import 'dart:async'; // Used for the "Timer" (the live clock)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Helps us turn numbers into "10:30 AM" or "Monday"
import 'package:geolocator/geolocator.dart'; // The GPS tool
import 'package:geocoding/geocoding.dart'; // Turns GPS coordinates into a street address
import 'package:flutter_map/flutter_map.dart'; // The map widget
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
  // --- The Clock & Strings ---
  late String _timeString; // e.g., "12:00:00 PM"
  late String _dateString; // e.g., "Monday, July 1"
  Timer? _clockTimer; // Store timer reference so it can be cancelled

  Map<String, dynamic>? _user;
  bool _isLoading = true; // Shows a "shimmer" effect while loading
  bool _isCheckedIn = false; // Is the user currently working?
  
  // --- Location Stuff ---
  String _currentAddress = "Fetching location...";
  LatLng _currentPosition = const LatLng(0, 0); // (0,0) is the middle of the ocean!
  final MapController _mapController = MapController();

  // --- Animations ---
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation; // Makes the Check-In button "throb"

  // --- Dashboard Stats ---
  String _todayHours = "0.0";
  String _monthHours = "0.0";
  String _attendanceRate = "0%";
  Map<String, dynamic> _leaveBalance = {'total': 0, 'used': 0, 'remaining': 0};

  bool _isInsideRadius = false; // Is the user close enough to the office?
  Map<String, dynamic>? _settings;

  String? _todayHoliday;
  String? _holidayType;
  List<dynamic> _upcomingHolidays = [];

  @override
  void initState() {
    super.initState();
    // Setup the clock immediately
    _timeString = _formatDateTime(DateTime.now());
    _dateString = _formatDate(DateTime.now());
    
    // Timer.periodic runs every 1 second to update the clock numbers
    // ANR Fix: Store timer reference so we can cancel it in dispose()
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());

    // Setup the "throbbing" animation for the button
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _initializeData(); // Fetch user info, GPS, and stats
  }

  @override
  void dispose() {
    _clockTimer?.cancel(); // ANR Fix: Cancel the 1-second timer to prevent memory leaks
    _animationController.dispose(); // Clean up memory
    super.dispose();
  }

  // --- Data Loading: Getting everything ready ---
  Future<void> _initializeData() async {
    // ANR Fix: Load user first (needed for stats), then run location + stats in PARALLEL
    // Previously these ran sequentially, blocking the UI for 3x the time
    await _loadUser();
    await Future.wait([
      _getCurrentLocation(),
      _loadStats(),
    ]);
  }

  // Load the user from the vault and check if they are already working
  Future<void> _loadUser() async {
    final user = await ApiService.getStoredUser();
    if (mounted) setState(() => _user = user);
    if (user != null) {
      final isCheckedIn = await ApiService.getCheckInStatus(user['id']);
      if (mounted) setState(() => _isCheckedIn = isCheckedIn);
    }
  }

  // This is the "Brain" of the dashboard. It calculates hours and attendance %.
  Future<void> _loadStats() async {
    if (_user == null) return;
    try {
      // We fetch 3 things: Attendance History, Leave Balance, and Holidays
      final history = await ApiService.getAttendance(_user!['id']);
      final leave = await ApiService.getLeaveBalance(_user!['id']);
      final holidays = await ApiService.getHolidays();

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      String? holidayName;
      String? holidayType;
      List<dynamic> upcoming = [];

      // Check if today is a holiday
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
      if (upcoming.length > 5) upcoming = upcoming.sublist(0, 5); // Just show top 5

      if (mounted) {
        setState(() {
          _todayHoliday = holidayName;
          _holidayType = holidayType;
          _upcomingHolidays = upcoming;
        });
      }

      // --- Math Time! ---
      double totalHours = 0;
      double todayHours = 0;
      int presentDays = 0;

      // Loop through all attendance records to count hours
      for (var record in history) {
        final checkIn = DateTime.parse(record['checkInTime']);
        
        // Is this record from TODAY?
        if (checkIn.day == now.day && checkIn.month == now.month && checkIn.year == now.year) {
          if (record['checkOutTime'] != null) {
            final checkOut = DateTime.parse(record['checkOutTime']);
            todayHours += checkOut.difference(checkIn).inMinutes / 60.0;
          } else {
            // Still working! Calculate hours from check-in until NOW
            todayHours += now.difference(checkIn).inMinutes / 60.0;
          }
        }

        // Is this record from THIS MONTH?
        if (checkIn.month == now.month && checkIn.year == now.year) {
          presentDays++;
          if (record['checkOutTime'] != null) {
            final checkOut = DateTime.parse(record['checkOutTime']);
            totalHours += checkOut.difference(checkIn).inMinutes / 60.0;
          }
        }
      }

      // Calculate Attendance Percentage (How many days present vs total working days)
      double totalWorkingDaysCount = 0;
      final Set<String> weekOffDays = (_user?['weekOffs'] ?? 'Sunday').split(',').map((s) => s.trim()).toSet();

      try {
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        for (int d = 1; d <= daysInMonth; d++) {
          final date = DateTime(now.year, now.month, d);
          final dayName = DateFormat('EEEE').format(date);
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          
          final holiday = holidays.firstWhere((h) => h['date'] == dateStr, orElse: () => null);

          // If it's not a weekend and not a public holiday, it's a working day!
          if (!weekOffDays.contains(dayName)) {
            if (holiday == null || holiday['type'] == 'Optional') {
              totalWorkingDaysCount += 1.0;
            } else if (holiday['duration'] == 'Half Day') {
              totalWorkingDaysCount += 0.5;
            }
          }
        }
      } catch (_) {
        totalWorkingDaysCount = 22.0; // Fallback to 22 days if calc fails
      }

      if (totalWorkingDaysCount == 0) totalWorkingDaysCount = 1.0;
      double rate = (presentDays / totalWorkingDaysCount) * 100;

      if (mounted) {
        setState(() {
          _todayHours = todayHours.toStringAsFixed(1);
          _monthHours = totalHours.toStringAsFixed(1);
          _attendanceRate = "${rate.toInt()}%";
          _leaveBalance = leave;
          _isLoading = false; // Hide the loading spinner/shimmer
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _getTime() {
    // ANR Fix: Compute strings first, then call setState only if values changed
    // Reduces unnecessary widget rebuilds triggered by the 1-second clock timer
    final DateTime now = DateTime.now();
    final newTime = _formatDateTime(now);
    final newDate = _formatDate(now);
    if (mounted && (newTime != _timeString || newDate != _dateString)) {
      setState(() {
        _timeString = newTime;
        _dateString = newDate;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) => DateFormat('hh:mm:ss a').format(dateTime);
  String _formatDate(DateTime dateTime) => DateFormat('EEEE, MMMM d, y').format(dateTime);

  // --- Location & Geofencing ---
  // This is the "Security Guard". It checks if you are actually at work.
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Is GPS turned on?
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    // 2. Do we have permission to use GPS?
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // 3. Get the coordinates (Lat/Long)
    final position = await Geolocator.getCurrentPosition();

    bool isInside = false;
    try {
      _settings ??= await ApiService.getSettings();
      // If the company doesn't require geofencing, they are "always inside"
      if (_settings != null && _settings!['geofenceEnabled'] == 0) {
        isInside = true;
      } else if (_settings != null && _settings!['officeLat'] != null) {
        // Calculate the distance between the phone and the office
        final double officeLat = (_settings!['officeLat'] as num).toDouble();
        final double officeLong = (_settings!['officeLong'] as num).toDouble();
        final double officeRadius = (_settings!['officeRadiusMeters'] as num?)?.toDouble() ?? 100.0;
        
        double distance = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          officeLat, officeLong,
        );
        // Is the distance less than the office radius (e.g., 100 meters)?
        isInside = distance <= officeRadius;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isInsideRadius = isInside;
        // Move the map to show the new location
        _mapController.move(_currentPosition, 15.0);
      });
    }

    // 4. Turn the coordinates into a readable address (e.g., "Main St 123")
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

  // --- The Check-In Button Logic ---
  Future<void> _handleCheckIn() async {
    // 1. Double check geofencing (Safety first!)
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

    // 2. Take a Selfie! (Verification)
    XFile? image;
    _settings = await ApiService.getSettings();
    
    if (_settings != null && _settings!['cameraAuthEnabled'] != 0) {
      final picker = ImagePicker();
      image = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
      if (image == null) return; // User cancelled the camera
    }

    setState(() => _isLoading = true);
    try {
      // 3. Send everything to the server
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
      
      // 4. Navigate to the Checkout screen automatically
      Navigator.pushNamed(context, '/checkout');
      _loadStats(); // Refresh the stats row
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we're still loading data and don't even have a user name, show a loading animation
    if (_isLoading && _user == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: PulseShimmer.list(count: 4, itemHeight: 100),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          Row(
            children: [
              // Shows company logo or user's face
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
                    // Show the shift timing (e.g., Morning Shift)
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
              // --- Geofence Badge ---
              // Shows a green "In Office" or red "Outside" sticker
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

          // --- 2. Holiday Banner ---
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

          // --- 3. The Digital Clock ---
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
                        style: TextStyle(fontWeight: FontWeight.w800, color: PulseColors.textPrimary),
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

          // --- 4. Stats Row ---
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

          // --- 5. Leave Balance ---
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
                        '${_leaveBalance['remaining']} remaining of ${_leaveBalance['total']} accrued',
                        style: PulseTextStyles.body,
                      ),
                      if (_leaveBalance['totalYearly'] != null)
                        Text(
                          '${_leaveBalance['totalYearly']}/year',
                          style: PulseTextStyles.caption.copyWith(fontSize: 11),
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

          // --- 6. Upcoming Holidays ---
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

          // --- 7. The Mini-Map ---
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
                      // Draw the office geofence circle
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
                      // Show the user's current pin
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
                  // The small address bar at the bottom of the map
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

          // --- 8. The Big Action Button ---
          if (!_isCheckedIn)
            ScaleTransition(
              scale: _pulseAnimation, // The "throb" effect
              child: GestureDetector(
                onTap: (_isLoading || !_isInsideRadius) ? null : _handleCheckIn,
                child: Container(
                  width: double.infinity,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    // Blue gradient if inside office, grey if outside
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
            // If already checked in, show a way to go to the Checkout screen
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

  // --- Helper: The small Stat Boxes ---
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
