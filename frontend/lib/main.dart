import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/pulse_theme.dart';
import 'core/providers/branding_provider.dart';
import 'core/services/firebase_service.dart';

import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/admin_login_screen.dart';
import 'features/auth/screens/admin_register_screen.dart';
import 'features/attendance/screens/splash_screen.dart';
import 'features/attendance/screens/main_container.dart';
import 'features/attendance/screens/attendance_history_screen.dart';
import 'features/attendance/screens/checkout_screen.dart';
import 'features/attendance/screens/notification_screen.dart';
import 'features/leaves/screens/leave_screen.dart';
import 'features/leaves/screens/user_holidays_screen.dart';
import 'features/payroll/screens/user_shifts_screen.dart';
import 'features/payroll/screens/user_payslips_screen.dart';
import 'features/profile/screens/change_password_screen.dart';
import 'features/admin/screens/admin_container.dart';
import 'features/admin/screens/admin_attendance_screen.dart';
import 'features/admin/screens/admin_employees_screen.dart';
import 'features/admin/screens/admin_leaves_screen.dart';
import 'features/admin/screens/admin_reports_screen.dart';
import 'features/admin/screens/admin_payslips_screen.dart';
import 'features/admin/screens/admin_settings_screen.dart';
import 'features/admin/screens/admin_holidays_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: TimeTrackerApp(),
    ),
  );
}

class TimeTrackerApp extends ConsumerWidget {
  const TimeTrackerApp({super.key});

  static final Map<String, WidgetBuilder> _routes = {
    '/login': (context) => const LoginScreen(),
    '/register': (context) => const RegisterScreen(),
    '/home': (context) => const MainContainer(),
    '/history': (context) => const AttendanceHistoryScreen(),
    '/leave': (context) => const LeaveScreen(),
    '/admin': (context) => const AdminContainer(),
    '/admin-attendance': (context) => AdminAttendanceScreen(),
    '/admin-employees': (context) => AdminEmployeesScreen(),
    '/admin-leaves': (context) => AdminLeavesScreen(),
    '/edit-profile': (context) => MainContainer(),
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
    '/admin-login': (context) => const AdminLoginScreen(),
    '/admin-register': (context) => const AdminRegisterScreen(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(brandingProvider);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trackzo',
      theme: PulseTheme.light(),
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        final builder = _routes[settings.name];
        if (builder != null) {
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) =>
                builder(context),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.03, 0),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 250),
          );
        }
        return null;
      },
    );
  }
}
