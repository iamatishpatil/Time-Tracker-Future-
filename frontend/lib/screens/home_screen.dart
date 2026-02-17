import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import 'checkout_screen.dart';
import 'attendance_history_screen.dart';
import '../widgets/common/glass_card.dart';
import '../widgets/common/gradient_button.dart';
import '../widgets/custom_drawer.dart';
import 'leave_screen.dart';
import 'edit_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String _currentTime = '';
  String _currentDate = '';
  late Timer _timer;
  bool _isCheckedIn = false;
  Map<String, dynamic>? _user;
  List<dynamic> _history = [];
  bool _isLoading = false;
  
  // Map and Location
  LatLng _currentPosition = const LatLng(0, 0);
  String _currentAddress = 'Fetching location...';
  final MapController _mapController = MapController();

  // Dashboard Stats
  String _todayHours = "00:00:00";
  String _monthHours = "0.0";
  String _attendanceRate = "0%";
  
  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Scaffold Key
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
      if (_isCheckedIn) _calculateDashboardStats();
    });
    _loadUserData();
    _getCurrentLocation();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
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
        _checkStatus();
        _loadHistory();
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkStatus() async {
    if (_user == null) return;
    try {
      final status = await ApiService.getCheckInStatus(_user!['id']);
      if (mounted) setState(() => _isCheckedIn = status);
    } catch (e) {
      debugPrint('Error checking status: $e');
    }
  }

  Future<void> _loadHistory() async {
    if (_user == null) return;
    try {
      final history = await ApiService.getAttendance(_user!['id']);
      if (mounted) {
        setState(() => _history = history);
        _calculateDashboardStats();
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
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

  void _calculateDashboardStats() {
    if (_history.isEmpty && !_isCheckedIn) return;

    double totalMonthHours = 0;
    int presentDays = 0;
    Set<String> uniqueDays = {};

    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    for (var record in _history) {
      final checkIn = DateTime.parse(record['checkInTime']).toLocal();
      if (checkIn.isAfter(firstDayOfMonth)) {
        uniqueDays.add(DateFormat('yyyy-MM-dd').format(checkIn));
        
        if (record['checkOutTime'] != null) {
          final checkOut = DateTime.parse(record['checkOutTime']).toLocal();
          totalMonthHours += checkOut.difference(checkIn).inMinutes / 60.0;
        }
      }
    }

    presentDays = uniqueDays.length;
    int totalWorkingDays = now.day; // Simplification: days passed in month
    double rate = (presentDays / totalWorkingDays) * 100;

    String todayHrs = "00:00:00";
    if (_isCheckedIn && _history.isNotEmpty) {
      // Find active session
      final activeSession = _history.firstWhere((r) => r['checkOutTime'] == null, orElse: () => null);
      if (activeSession != null) {
        final checkIn = DateTime.parse(activeSession['checkInTime']).toLocal();
        final diff = DateTime.now().difference(checkIn);
        todayHrs = _formatDuration(diff);
      }
    }

    if (mounted) {
      setState(() {
        _monthHours = totalMonthHours.toStringAsFixed(1);
        _attendanceRate = "${rate.toInt()}%";
        _todayHours = todayHrs;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
  
  Future<void> _handleCheckIn() async {
    setState(() => _isLoading = true);
    
    // Use current state location if available
    double lat = _currentPosition.latitude;
    double long = _currentPosition.longitude;
    String address = _currentAddress;

    // Capture Photo
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);

    if (photo == null && mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selfie is required for check-in')));
       setState(() => _isLoading = false);
       return;
    }

    try {
      await ApiService.checkIn(_user!['id'], lat: lat, long: long, address: address, photo: photo);
      if (mounted) {
        setState(() => _isCheckedIn = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in Successful!')));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ApiService.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _user != null ? CustomDrawer(user: _user!) : null,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6200EA), Color(0xFF651FFF), Color(0xFF00BFA5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(_scaffoldKey),
                
                // Content
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Clock Card
                          GlassCard(
                            padding: const EdgeInsets.all(24),
                            borderRadius: 24,
                            child: Column(
                              children: [
                                Text(
                                  _currentTime,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF311B92),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _currentDate,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Performance Dashboard
                          GlassCard(
                            padding: const EdgeInsets.all(20),
                            borderRadius: 24,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem("TODAY'S HRS", _todayHours, Icons.timer_outlined),
                                _buildStatItem("THIS MONTH", _monthHours, Icons.calendar_month_outlined),
                                _buildStatItem("ATTENDANCE", _attendanceRate, Icons.percent),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Live Map View
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: SizedBox(
                              height: 200,
                              child: Stack(
                                children: [
                                  FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter: _currentPosition,
                                      initialZoom: 15.0,
                                    ),
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
                                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    bottom: 10,
                                    left: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 16, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _currentAddress,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

                          // Check In Button (Animated)
                          if (!_isCheckedIn)
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Center(
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF00BFA5), Color(0xFF651FFF)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00BFA5).withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _isLoading ? null : _handleCheckIn,
                                      borderRadius: BorderRadius.circular(100),
                                      child: _isLoading 
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              Icon(Icons.touch_app, size: 48, color: Colors.white),
                                              SizedBox(height: 8),
                                              Text(
                                                'TAP TO\nCHECK IN',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
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
                                  text: 'GO TO DASHBOARD',
                                  onPressed: () => Navigator.pushNamed(context, '/checkout'),
                                  colors: const [Color(0xFF6200EA), Color(0xFF651FFF)],
                               ),
                             ),

                          const SizedBox(height: 32),
                          
                          // Quick Actions
                          const Text(
                             'Quick Actions',
                             style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF311B92)),
                          ),
                          const SizedBox(height: 16),
                           GridView.count(
                             crossAxisCount: 3,
                             crossAxisSpacing: 12,
                             mainAxisSpacing: 12,
                             shrinkWrap: true,
                             physics: const NeverScrollableScrollPhysics(),
                             children: [
                               _buildActionCard(
                                 icon: Icons.history, 
                                 label: 'History', 
                                 color: Colors.blue,
                                 onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen())),
                               ),
                               _buildActionCard(
                                 icon: Icons.beach_access, 
                                 label: 'Leave', 
                                 color: Colors.orange,
                                 onTap: () => Navigator.pushNamed(context, '/leave'),
                               ),
                               _buildActionCard(
                                 icon: Icons.person, 
                                 label: 'Profile', 
                                 color: Colors.purple,
                                 onTap: () => Navigator.pushNamed(context, '/profile'),
                               ),
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

  Widget _buildHeader(GlobalKey<ScaffoldState> scaffoldKey) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 28),
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
          ),
          Row(
            children: [
              if (_user?['profilePicture'] != null)
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage('http://192.168.1.8:3000${_user!['profilePicture']}'),
                )
              else
                const CircleAvatar(radius: 24, child: Icon(Icons.person)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome Back,', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(
                    _user?['fullName'] ?? 'User',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 12),
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6200EA)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF311B92)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
