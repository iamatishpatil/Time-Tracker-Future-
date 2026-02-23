// --- 1. Imports Section ---
// We bring in external libraries and our own files here.
import 'package:flutter/material.dart'; // Core Flutter UI library
import 'package:flutter/services.dart'; // Helps talk to the phone system (status bar, etc.)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/pulse_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_attendance_screen.dart';
import 'screens/admin/admin_employees_screen.dart';
import 'screens/admin/admin_leaves_screen.dart';
import 'screens/admin/admin_reports_screen.dart';
import 'screens/attendance_history_screen.dart';
import 'screens/leave_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/main_container.dart';
import 'screens/notification_screen.dart';
import 'screens/user_holidays_screen.dart';
import 'screens/user_shifts_screen.dart';
import 'screens/user_payslips_screen.dart';
import 'screens/admin/admin_payslips_screen.dart';
import 'screens/admin/admin_container.dart';
import 'screens/admin/admin_holidays_screen.dart';

// --- 2. The Main Function ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // We wrap the entire app in ProviderScope for Riverpod state management
  runApp(
    const ProviderScope(
      child: TimeTrackerApp(),
    ),
  );
}

// --- 3. The Root App Widget ---
class TimeTrackerApp extends ConsumerWidget {
  const TimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Time Tracker',
      theme: PulseTheme.light(),
      
      // Default to Slash Screen for branding and session initialization
      home: const SplashScreen(),

      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const MainContainer(),
        '/history': (context) => const AttendanceHistoryScreen(),
        '/leave': (context) => const LeaveScreen(),
        '/admin': (context) => const AdminContainer(),
        '/admin-attendance': (context) => AdminAttendanceScreen(),
        '/admin-employees': (context) => AdminEmployeesScreen(),
        '/admin-leaves': (context) => AdminLeavesScreen(),
        '/edit-profile': (context) => MainContainer(), // Updated for simplicity
        '/change-password': (context) => ChangePasswordScreen(),
        '/notifications': (context) => NotificationScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/user-holidays': (context) => const UserHolidaysScreen(),
        '/user-shifts': (context) => UserShiftsScreen(),
        '/user-payslips': (context) => const UserPayslipsScreen(),
        '/admin-reports': (context) => const AdminReportsScreen(),
        '/admin-payslips': (context) => const AdminPayslipsScreen(),
        '/admin-settings': (context) => const AdminSettingsScreen(),
        '/admin-holidays': (context) => const AdminHolidaysScreen(),
      },
    );
  }
}
