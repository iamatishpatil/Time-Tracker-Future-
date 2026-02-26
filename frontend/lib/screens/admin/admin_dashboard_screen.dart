// --- 1. The Admin Dashboard (Control Center) ---
// This is the first screen the Boss/Admin sees. It provides a "Birds Eye View"
// of the whole company's attendance for the day.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';
import '../../core/widgets/pulse_shimmer.dart';

import '../../core/widgets/pulse_scaffold.dart';
import '../../core/widgets/branded_logo.dart';
import '../../services/api_service.dart';
import '../../widgets/admin_drawer.dart';
import 'admin_attendance_screen.dart';
import 'admin_employees_screen.dart';
import 'admin_leaves_screen.dart';
import 'admin_payroll_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_shifts_screen.dart';
import 'admin_holidays_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/branding_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  final bool isTab;
  const AdminDashboardScreen({super.key, this.isTab = false});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _user;
  List<dynamic> _upcomingHolidays = [];
  List<dynamic> _recentActivity = [];
  Map<String, dynamic>? _settings;
  bool _isLoading = true;
  String? _todayHoliday;
  String? _holidayType;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // The Big Fetch: Gets everything needed for the dashboard in one go.
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await ApiService.getStoredUser();
      
      // Sync branding with the current user's company
      if (user != null && user['company'] != null) {
        await ref.read(brandingProvider.notifier).fetchBranding(company: user['company']);
      }

      // Fetch all data in parallel for better performance and to avoid sequential bottlenecks
      final results = await Future.wait([
        ApiService.getAdminStats(),
        ApiService.getAllAttendance(limit: 5), // Fetch only what's needed for the recent list
        ApiService.getSettings(),
        ApiService.getHolidays(),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final recent = results[1] as List<dynamic>;
      final settings = results[2] as Map<String, dynamic>;
      final holidays = results[3] as List<dynamic>;

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
        // If it's today, we show it in the banner, so we only put actual FUTURE holidays in the list
        if (hDate.isAfter(DateTime(now.year, now.month, now.day, 23, 59))) {
          upcoming.add(h);
        }
      }
      upcoming.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
      if (upcoming.length > 5) upcoming = upcoming.sublist(0, 5);

      // Note: Backend already sorts by checkInTime DESC, so we don't need expensive client-side sorting anymore.

      if (mounted) {
        setState(() {
          _user = user;
          _stats = stats;
          _todayHoliday = holidayName;
          _holidayType = holidayType;
          _upcomingHolidays = upcoming;
          _recentActivity = recent;
          _settings = settings;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: _loadData,
      child: _isLoading
          ? Padding(padding: const EdgeInsets.all(20), child: PulseShimmer.grid())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header (Shows Company Logo + Greeting)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_getGreeting()},', style: PulseTextStyles.body.copyWith(color: PulseColors.textSecondary)),
                            Text(_user?['fullName'] ?? 'Admin', style: PulseTextStyles.h2),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: PulseColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text(_user?['role']?.toUpperCase() ?? 'ADMINISTRATOR', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.primary, fontSize: 10, letterSpacing: 1)),
                            ),
                          ],
                        ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1),
                      ),
                      Animate(child: BrandedLogo(size: 60, showText: false)).scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Holiday Banner (Matches Home Screen)
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
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 20),
                  ],

                  Text('Overview', style: PulseTextStyles.h3),
                  const SizedBox(height: 14),

                  // --- The Stats Grid ---
                  // These 5 cards are the core of the Admin experience
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.15,
                    children: [
                      _stat('Total Staff', _stats?['totalEmployees']?.toString() ?? '0', PulseColors.accent, Icons.people, 0,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEmployeesScreen()))),
                      _stat('Present', _stats?['presentToday']?.toString() ?? '0', PulseColors.success, Icons.check_circle, 1,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAttendanceScreen()))),
                      _stat('Late', _stats?['lateToday']?.toString() ?? '0', PulseColors.warning, Icons.timer, 2,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAttendanceScreen()))),
                      _stat('Absent', _stats?['absentToday']?.toString() ?? '0', PulseColors.error, Icons.cancel, 3,
                          onTap: () => Navigator.pushNamed(context, '/admin-absent')),
                      _stat('On Leave', _stats?['onLeaveToday']?.toString() ?? '0', PulseColors.primary, Icons.beach_access, 4,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminLeavesScreen()))),
                    ],
                  ),

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Activity', style: PulseTextStyles.h3),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAttendanceScreen())),
                        child: Text('View Details', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.primary)),
                      ),
                    ],
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 8),
                  _buildRecentActivity(),

                  if (_upcomingHolidays.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Upcoming Holidays', style: PulseTextStyles.h3),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminHolidaysScreen())),
                          child: Text('View All', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.primary)),
                        ),
                      ],
                    ).animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _upcomingHolidays.length,
                        itemBuilder: (context, index) {
                          final h = _upcomingHolidays[index];
                          final isPublic = h['type'] == 'Public';
                          final color = isPublic ? PulseColors.success : PulseColors.warning;
                          return Container(
                            width: 155,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: color.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(h['name'], style: PulseTextStyles.captionBold.copyWith(color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(DateFormat('MMM d, yyyy').format(DateTime.parse(h['date'])), style: PulseTextStyles.caption),
                                const SizedBox(height: 2),
                                Text(h['duration'] == 'Half Day' ? 'Half Day' : h['type'], style: PulseTextStyles.caption.copyWith(color: color, fontSize: 10)),
                              ],
                            ),
                          ).animate().fadeIn(delay: (600 + (index * 100)).ms).slideX(begin: 0.2);
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  Text('Quick Actions', style: PulseTextStyles.h3).animate().fadeIn(delay: 700.ms),
                  const SizedBox(height: 14),

                  // --- Quick Actions Grid ---
                  // These are shortcuts to every management screen.
                  Builder(
                    builder: (context) {
                      final actions = [
                        {'label': 'Holidays', 'icon': Icons.celebration, 'color': Colors.orange, 'onTap': () => Navigator.pushNamed(context, '/admin-holidays')},
                        if (_settings?['payrollEnabled'] != 0)
                          {'label': 'Payroll', 'icon': Icons.payments, 'color': PulseColors.success, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPayrollScreen()))},
                        {'label': 'Reports', 'icon': Icons.assessment, 'color': const Color(0xFF26A69A), 'onTap': () => Navigator.pushNamed(context, '/admin-reports')},
                        {'label': 'Shifts', 'icon': Icons.schedule, 'color': const Color(0xFFE91E63), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminShiftsScreen()))},
                      ];

                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: actions.length,
                        itemBuilder: (context, index) {
                          final a = actions[index];
                          return _action(
                            a['label'] as String,
                            a['icon'] as IconData,
                            a['color'] as Color,
                            index, // Contour indices for smooth animation
                            a['onTap'] as VoidCallback,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );

    if (widget.isTab) return content;

    return PulseScaffold(
      title: _stats != null ? 'Admin Dashboard' : 'Admin Panel',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
      ],
      drawer: _user != null ? AdminDrawer(user: _user!, onUserUpdated: (u) => setState(() => _user = u)) : null,
      body: content,
    );
  }

  Widget _buildRecentActivity() {
    if (_recentActivity.isEmpty) {
      return PulseCard(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text('No recent activity recorded today.', style: PulseTextStyles.caption),
        ),
      );
    }

    return Column(
      children: _recentActivity.asMap().entries.map((entry) {
        final index = entry.key;
        final log = entry.value;
        final checkIn = DateTime.parse(log['checkInTime']).toLocal();
        final isLate = log['status'] == 'Late';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PulseCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: PulseColors.surfaceVariant,
                      backgroundImage: log['profilePicture'] != null ? NetworkImage(ApiService.getImageUrl(log['profilePicture'])) : null,
                      child: log['profilePicture'] == null ? const Icon(Icons.person, size: 20, color: PulseColors.textHint) : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isLate ? PulseColors.error : PulseColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: PulseColors.surface, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log['fullName'] ?? 'Unknown', style: PulseTextStyles.bodyBold.copyWith(fontSize: 14)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 10, color: PulseColors.textSecondary.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(DateFormat('hh:mm a').format(checkIn), style: PulseTextStyles.caption.copyWith(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isLate ? 'LATE ENTRY' : 'ON TIME',
                      style: PulseTextStyles.captionBold.copyWith(
                        color: isLate ? PulseColors.error : PulseColors.success,
                        fontSize: 8,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Check In', style: PulseTextStyles.caption.copyWith(fontSize: 10, color: PulseColors.textHint)),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (450 + (index * 50)).ms).slideX(begin: -0.05);
      }).toList(),
    );
  }

  Widget _stat(String title, String value, Color color, IconData icon, int index, {VoidCallback? onTap}) {
    return PulseCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(icon, color: color.withOpacity(0.05), size: 60),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(value, style: PulseTextStyles.h2.copyWith(fontSize: 24, height: 1)),
              const SizedBox(height: 4),
              Text(title, style: PulseTextStyles.captionBold.copyWith(fontSize: 11, color: PulseColors.textSecondary)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (200 + (index * 80)).ms).scale(duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _action(String title, IconData icon, Color color, int index, VoidCallback onTap) {
    return PulseCard(
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: PulseColors.brandGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PulseTextStyles.captionBold.copyWith(fontSize: 10, letterSpacing: 0.2),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (800 + (index * 50)).ms).slideY(begin: 0.1);
  }
}
