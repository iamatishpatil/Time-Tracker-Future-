import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/common/glass_card.dart';
import '../widgets/common/gradient_button.dart';
import 'attendance_history_screen.dart';
import 'checkout_screen.dart';

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

  // Stats
  String _todayHours = "0.0";
  String _monthHours = "0.0";
  String _attendanceRate = "0%";
  Map<String, dynamic> _leaveBalance = {'total': 0, 'used': 0, 'remaining': 0};
  
  // Geofencing
  bool _isInsideRadius = false;
  Map<String, dynamic>? _settings;

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
      
      double totalHours = 0;
      double todayHours = 0;
      int presentDays = 0;
      final now = DateTime.now();
      
      for (var record in history) {
        final checkIn = DateTime.parse(record['checkInTime']);
        
        // Today's hours
        if (checkIn.day == now.day && checkIn.month == now.month && checkIn.year == now.year) {
          if (record['checkOutTime'] != null) {
            final checkOut = DateTime.parse(record['checkOutTime']);
            todayHours += checkOut.difference(checkIn).inMinutes / 60.0;
          } else {
            // Still checked in
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

      int totalWorkingDays = 22; // Approximation
      double rate = (presentDays / totalWorkingDays) * 100;

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
    final String formattedDateTime = _formatDateTime(now);
    final String formattedDate = _formatDate(now);
    if (mounted) {
      setState(() {
        _timeString = formattedDateTime;
        _dateString = formattedDate;
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
    
    // Check Geofencing
    bool isInside = false;
    try {
      if (_settings == null) _settings = await ApiService.getSettings();
      if (_settings != null && _settings!['officeLat'] != null) {
        double distance = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          _settings!['officeLat'], _settings!['officeLong']
        );
        isInside = distance <= (_settings!['officeRadiusMeters'] ?? 100);
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
        photo: image
      );
      if (mounted) {
        setState(() => _isCheckedIn = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked In Successfully!')));
        Navigator.pushNamed(context, '/checkout');
      }
      _loadStats();
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3E5F5),
      child: Stack(
        children: [
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6200EA), Color(0xFF651FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: _user?['profilePicture'] != null 
                          ? NetworkImage(ApiService.getImageUrl(_user!['profilePicture'])) 
                          : null,
                        child: _user?['profilePicture'] == null ? const Icon(Icons.person, size: 30) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Welcome Back,', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Text(
                              _user?['fullName'] ?? 'User',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isInsideRadius ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _isInsideRadius ? Colors.green : Colors.red, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isInsideRadius ? Icons.check_circle : Icons.warning_amber_rounded,
                              color: _isInsideRadius ? Colors.green : Colors.red,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isInsideRadius ? 'Inside Office' : 'Outside Office',
                              style: TextStyle(
                                color: _isInsideRadius ? Colors.green : Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GlassCard(
                            padding: const EdgeInsets.all(24),
                            borderRadius: 24,
                            child: Column(
                              children: [
                                Text(_timeString, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF311B92))),
                                Text(_dateString, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatItem('Today Hrs', _todayHours, Colors.purple),
                                    _buildStatItem('Monthly Hrs', _monthHours, Colors.blue),
                                    _buildStatItem('Attendance', _attendanceRate, Colors.green),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
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
                                      if (_settings != null && _settings!['officeLat'] != null) ...[
                                        CircleLayer(
                                          circles: [
                                            CircleMarker(
                                              point: LatLng(_settings!['officeLat'], _settings!['officeLong']),
                                              color: Colors.blue.withValues(alpha: 0.3),
                                              borderStrokeWidth: 2,
                                              borderColor: Colors.blue,
                                              radius: (_settings!['officeRadiusMeters'] as num?)?.toDouble() ?? 100.0,
                                              useRadiusInMeter: true,
                                            ),
                                          ],
                                        ),
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              point: LatLng(_settings!['officeLat'], _settings!['officeLong']),
                                              width: 30,
                                              height: 30,
                                              child: const Icon(Icons.business, color: Colors.blue, size: 30),
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
                                            child: const Icon(Icons.person_pin_circle, color: Color(0xFF6200EA), size: 40),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    bottom: 10, left: 10, right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 16, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(_currentAddress, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          if (!_isCheckedIn)
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Center(
                                child: GestureDetector(
                                  onTap: _isLoading ? null : _handleCheckIn,
                                  child: Container(
                                    width: 180, height: 180,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF651FFF)]),
                                      boxShadow: [BoxShadow(color: const Color(0xFF00BFA5).withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 5)],
                                    ),
                                    child: Center(
                                      child: _isLoading 
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              Icon(Icons.touch_app, size: 48, color: Colors.white),
                                              SizedBox(height: 8),
                                              Text('TAP TO\nCHECK IN', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                            ],
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                             Center(
                               child: GradientButton(
                                  text: 'GO TO CHECKOUT',
                                  onPressed: () => Navigator.pushNamed(context, '/checkout'),
                                  colors: const [Color(0xFF6200EA), Color(0xFF651FFF)],
                               ),
                             ),

                          const SizedBox(height: 32),
                          const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF311B92))),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildActionCard(icon: Icons.history, label: 'History', color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen())))),
                              const SizedBox(width: 12),
                              Expanded(child: _buildActionCard(icon: Icons.beach_access, label: 'Leave', color: Colors.orange, onTap: () => Navigator.pushNamed(context, '/leave'))),
                              const SizedBox(width: 12),
                              Expanded(child: _buildActionCard(icon: Icons.person, label: 'Profile', color: Colors.purple, onTap: () => Navigator.pushNamed(context, '/profile'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildActionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
