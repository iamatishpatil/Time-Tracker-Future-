// Import Dart's JSON encoding/decoding library
import 'dart:convert';
// Import HTTP client for making API requests
import 'package:http/http.dart' as http;
// Import image picker for handling profile picture files
import 'package:image_picker/image_picker.dart';
// Import shared preferences for storing user data locally
import 'package:shared_preferences/shared_preferences.dart';
// Import dart:io for platform detection
import 'dart:io';
// Import intl for date formatting
import 'package:intl/intl.dart';

// ApiService class contains all methods for communicating with the backend server
class ApiService {
  // Get the base URL for API requests based on the platform
  // Android emulator uses 10.0.2.2 to access host machine's localhost
  // Other platforms (Windows, iOS, Web) use localhost directly
  static String get baseUrl {
    // Return the Host PC's local IP address so physical devices on the same Wi-Fi can connect
    return 'http://192.168.1.9:3000/api';
  }

  // Get full image URL by replacing /api with empty string to get server root
  static String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return baseUrl.replaceAll('/api', '') + path;
  }
  // Register a new user with profile picture and user details
  // Parameters:
  //   - fields: Map containing all user information (name, email, password, etc.)
  //   - image: Optional profile picture file from image picker
  // Returns: Map with registration response data
  // Throws: Exception if registration fails
  static Future<Map<String, dynamic>> register(Map<String, String> fields, XFile? image) async {
    // Create URI for the register endpoint
    var uri = Uri.parse('$baseUrl/register');
    // Create multipart request (required for file uploads)
    var request = http.MultipartRequest('POST', uri);
    // Add all text fields to the request
    request.fields.addAll(fields);
    
    // If profile picture is provided, add it to the request
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('profilePicture', image.path));
    }

    try {
      // Send the request and get streamed response
      var streamedResponse = await request.send();
      // Convert streamed response to regular response
      var response = await http.Response.fromStream(streamedResponse);
      
      // Check if registration was successful (HTTP 200)
      if (response.statusCode == 200) {
        return json.decode(response.body); // Return parsed JSON response
      } else {
        // Try to parse error message from JSON
        String errorMessage = 'Failed to register';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) errorMessage = errorData['error'];
        } catch (_) {
          errorMessage = response.body;
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ========== USER LOGIN METHOD ==========
  // Authenticate user with mobile number and password
  // Parameters:
  //   - mobileNumber: User's mobile number (used as username)
  //   - password: User's password
  // Returns: Map with login response including user data
  // Throws: Exception if login fails
  // Side effect: Stores user data in SharedPreferences for persistence
  static Future<Map<String, dynamic>> login(String mobileNumber, String password) async {
    try {
      // Send POST request to login endpoint with credentials
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'}, // Specify JSON content type
        body: json.encode({'mobileNumber': mobileNumber, 'password': password}), // Encode credentials as JSON
      );

      // Check if login was successful
      if (response.statusCode == 200) {
        final data = json.decode(response.body); // Parse response JSON
        // Store user data locally for future sessions
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(data['user'])); // Save user object as JSON string
        return data;
      } else {
        String errorMessage = 'Failed to login';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) errorMessage = errorData['error'];
        } catch (_) {
          errorMessage = response.body;
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ========== GET STORED USER METHOD ==========
  // Retrieve user data from local storage (SharedPreferences)
  // Returns: Map with user data if logged in, null if not logged in
  // Used to check if user is already logged in when app starts
  static Future<Map<String, dynamic>?> getStoredUser() async {
     final prefs = await SharedPreferences.getInstance();
     String? userStr = prefs.getString('user'); // Get stored user JSON string
     if (userStr != null) {
       return json.decode(userStr); // Parse and return user object
     }
     return null; // No user stored (not logged in)
  }

  // ========== UPDATE USER METHOD ==========
  // Update user details
  // Parameters:
  //   - userId: ID of the user to update
  //   - fields: Map of fields to update
  // Returns: Updated user map
  static Future<Map<String, dynamic>> updateUser(int userId, Map<String, dynamic> fields, {XFile? image}) async {
    var uri = Uri.parse('$baseUrl/user/$userId');
    var request = http.MultipartRequest('PUT', uri);
    
    // Add all text fields to the request
    fields.forEach((key, value) {
      if (value != null) {
        request.fields[key] = value.toString();
      }
    });

    // If profile picture is provided, add it to the request
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('profilePicture', image.path));
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Update local storage ONLY if the updated user is the currently logged-in user
        final prefs = await SharedPreferences.getInstance();
        final currentUserStr = prefs.getString('user');
        if (currentUserStr != null) {
          final Map<String, dynamic> currentLoggedUser = json.decode(currentUserStr);
          if (currentLoggedUser['id'] == userId) {
            await prefs.setString('user', json.encode(data['user']));
          }
        }
        return data['user'];
      } else {
        throw Exception('Failed to update user: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  // ========== CHECK-IN METHOD ==========
  // Record user check-in with optional location data and photo
  // Parameters:
  //   - userId: ID of the user checking in
  //   - lat: Optional latitude coordinate
  //   - long: Optional longitude coordinate
  //   - address: Optional human-readable address
  //   - photo: Optional photo file
  // Throws: Exception if check-in fails (e.g., already checked in)
  static Future<void> checkIn(int userId, {double? lat, double? long, String? address, XFile? photo}) async {
    var uri = Uri.parse('$baseUrl/checkin');
    var request = http.MultipartRequest('POST', uri);
    
    request.fields['userId'] = userId.toString();
    if (lat != null) request.fields['lat'] = lat.toString();
    if (long != null) request.fields['long'] = long.toString();
    if (address != null) request.fields['address'] = address;

    if (photo != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        String errorMessage = 'Failed to check in';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) errorMessage = errorData['error'];
        } catch (_) {
          errorMessage = response.body;
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
       throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ========== CHECK-OUT METHOD ==========
  // Record user check-out with optional location data and photo
  // Parameters:
  //   - userId: ID of the user checking out
  //   - lat: Optional latitude coordinate
  //   - long: Optional longitude coordinate
  //   - address: Optional human-readable address
  //   - photo: Optional photo file
  // Throws: Exception if check-out fails (e.g., no active check-in)
  static Future<void> checkOut(int userId, {double? lat, double? long, String? address, XFile? photo}) async {
    var uri = Uri.parse('$baseUrl/checkout');
    var request = http.MultipartRequest('POST', uri);
    
    request.fields['userId'] = userId.toString();
    if (lat != null) request.fields['lat'] = lat.toString();
    if (long != null) request.fields['long'] = long.toString();
    if (address != null) request.fields['address'] = address;

    if (photo != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        String errorMessage = 'Failed to check out';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) errorMessage = errorData['error'];
        } catch (_) {
          errorMessage = response.body;
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
       throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ========== GET ATTENDANCE HISTORY METHOD ==========
  // Retrieve all attendance records for a specific user
  // Parameters:
  //   - userId: ID of the user
  // Returns: List of attendance records (each record is a Map)
  // Throws: Exception if request fails
  static Future<List<dynamic>> getAttendance(int userId) async {
    // Send GET request to fetch attendance history
    final response = await http.get(Uri.parse('$baseUrl/attendance/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body); // Return parsed list of attendance records
    } else {
      throw Exception('Failed to load attendance');
    }
  }

  // ========== GET CHECK-IN STATUS METHOD ==========
  // Check if user currently has an active check-in session
  // Parameters:
  //   - userId: ID of the user
  // Returns: true if user is checked in, false otherwise
  static Future<bool> getCheckInStatus(int userId) async {
    // Send GET request to check current status
    final response = await http.get(Uri.parse('$baseUrl/attendance/status/$userId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['isCheckedIn'] ?? false; // Return check-in status (default to false)
    }
    return false; // Return false if request fails
  }
  
  // ========== LOGOUT METHOD ==========
  // Clear user data from local storage (log out)
  // Side effect: Removes user data from SharedPreferences
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user'); // Remove stored user data
  }

  // --- OTP & Password Recovery ---

  // Send OTP
  static Future<Map<String, dynamic>> sendOtp({String? mobileNumber, String? email}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/otp/send'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'mobileNumber': ?mobileNumber,
        'email': ?email,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to send OTP: ${response.body}');
    }
  }

  // Verify OTP
  static Future<Map<String, dynamic>> verifyOtp({String? mobileNumber, String? email, required String otp}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'mobileNumber': ?mobileNumber,
        'email': ?email,
        'otp': otp,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to verify OTP: ${response.body}');
    }
  }

  // Reset Password
  static Future<void> resetPassword(String mobileNumber, String otp, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'mobileNumber': mobileNumber,
        'otp': otp,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to reset password: ${response.body}');
    }
  }

  // Change Password
  static Future<void> changePassword(int userId, String oldPassword, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/change-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to change password';
      throw Exception(error);
    }
  }

  // ============ LEAVE MANAGEMENT METHODS ============

  // Apply for leave
  static Future<void> applyLeave(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/leaves/apply'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to apply for leave: ${response.body}');
    }
  }

  // Get leave history
  static Future<List<dynamic>> getLeaveHistory(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/leaves/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load leave history');
    }
  }

  // Cancel Leave
  static Future<void> cancelLeave(int leaveId, int userId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/leaves/$leaveId/cancel'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId}),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to cancel leave';
      throw Exception(error);
    }
  }

  // Get leave balance
  static Future<Map<String, dynamic>> getLeaveBalance(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/leaves/balance/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load leave balance');
    }
  }

  // Get dynamic leave types
  static Future<List<String>> getLeaveTypes() async {
    final response = await http.get(Uri.parse('$baseUrl/leaves/types'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((t) => t.toString()).toList();
    } else {
      throw Exception('Failed to load leave types');
    }
  }

  // ============ ADMIN METHODS ============

  // Get Admin Dashboard Stats
  static Future<Map<String, dynamic>> getAdminStats() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/stats'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load admin stats');
    }
  }

  // Get All Employees
  static Future<List<dynamic>> getAllUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/users'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load users');
    }
  }

  // Get Absent Employees
  static Future<List<dynamic>> getAbsentEmployees() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/absent'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load absent employees');
    }
  }

  // Get All Attendance Records (with optional filters)
  static Future<List<dynamic>> getAllAttendance({int? userId, DateTime? startDate, DateTime? endDate, String? department}) async {
    final params = <String, String>{};
    if (userId != null) params['userId'] = userId.toString();
    if (startDate != null) params['startDate'] = DateFormat('yyyy-MM-dd').format(startDate);
    if (endDate != null) params['endDate'] = DateFormat('yyyy-MM-dd').format(endDate);
    if (department != null) params['department'] = department;
    final uri = Uri.parse('$baseUrl/admin/attendance').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load attendance records');
    }
  }

  // Update an attendance record (Admin edit)
  static Future<void> updateAttendance(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/attendance/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to update attendance';
      throw Exception(error);
    }
  }

  // Create manual attendance entry (Admin)
  static Future<void> createManualAttendance(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/attendance'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to create attendance';
      throw Exception(error);
    }
  }

  // Get All Leave Requests
  static Future<List<dynamic>> getAllLeaves() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/leaves'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load leave requests');
    }
  }

  // Update Leave Status (Approve/Reject)
  static Future<void> updateLeaveStatus(int id, String status, {String? rejectionReason}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/leaves/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'status': status, 'rejectionReason': rejectionReason}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update leave status');
    }
  }

  // Create New User
  static Future<void> createUser(Map<String, dynamic> userData, {XFile? image}) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/admin/users'));
    userData.forEach((key, value) {
      request.fields[key] = value.toString();
    });
    
    if (image != null) {
      var multipartFile = await http.MultipartFile.fromPath('profilePicture', image.path);
      request.files.add(multipartFile);
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to create user';
      throw Exception(error);
    }
  }

  // Delete User
  static Future<void> deleteUser(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/users/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete user');
    }
  }

  // Toggle Employee Active/Inactive Status
  static Future<void> toggleEmployeeActive(int id, bool isActive) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/users/$id/active'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'isActive': isActive ? 1 : 0}),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body)['error'] ?? 'Failed to update status';
      throw Exception(error);
    }
  }

  // ============ SHIFT MANAGEMENT METHODS ============

  // Get All Shifts
  static Future<List<dynamic>> getShifts() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/shifts'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load shifts');
    }
  }

  // Create Shift
  static Future<void> createShift(Map<String, dynamic> shiftData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/shifts'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(shiftData),
    );
     if (response.statusCode != 200) {
      throw Exception('Failed to create shift: ${response.body}');
    }
  }

  // ============ COMPANY SETTINGS METHODS ============

  // Get Settings
  static Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(Uri.parse('$baseUrl/settings'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load settings');
    }
  }

  // Update Settings
  static Future<void> updateSettings(Map<String, dynamic> settingsData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/settings'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(settingsData),
    );
     if (response.statusCode != 200) {
      throw Exception('Failed to update settings: ${response.body}');
    }
  }
  // ============ NOTIFICATIONS METHODS ============

  // Get User Notifications
  static Future<List<dynamic>> getNotifications(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/notifications/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  // Mark Notification as Read
  static Future<void> markNotificationRead(int id) async {
    final response = await http.put(Uri.parse('$baseUrl/notifications/$id/read'));
    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  // Get Attendance Report
  static Future<List<dynamic>> getAttendanceReport({DateTime? startDate, DateTime? endDate}) async {
    String query = '';
    if (startDate != null && endDate != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate);
      query = '?startDate=$startStr&endDate=$endStr';
    }
    
    final response = await http.get(Uri.parse('$baseUrl/admin/reports/attendance$query'));
     if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load report');
    }
  }
  // ============ SHIFT MANAGEMENT ============

  static Future<void> updateShift(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/shifts/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to update shift');
  }

  static Future<void> deleteShift(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/shifts/$id'));
    if (response.statusCode != 200) throw Exception('Failed to delete shift');
  }

  // ============ HOLIDAYS ============

  static Future<List<dynamic>> getHolidays() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/holidays'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load holidays');
  }

  static Future<void> addHoliday(String name, String date, {String type = 'Public', String duration = 'Full Day'}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/holidays'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'date': date,
        'type': type,
        'duration': duration,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to add holiday');
  }

  static Future<void> deleteHoliday(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/holidays/$id'));
    if (response.statusCode != 200) throw Exception('Failed to delete holiday');
  }

  // ============ LEAVE POLICIES ============

  static Future<List<dynamic>> getLeavePolicies() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/leave-policies'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load leave policies');
  }

  static Future<void> saveLeavePolicy(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/leave-policies'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to save policy');
  }

  static Future<void> adjustLeaveBalance(int userId, String leaveType, int totalDays) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/leave-balance'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId, 'leaveType': leaveType, 'totalDays': totalDays}),
    );
    if (response.statusCode != 200) throw Exception('Failed to adjust balance');
  }

  // ============ REPORTS ============

  static Future<List<dynamic>> getOvertimeReport({DateTime? startDate, DateTime? endDate}) async {
    String query = '';
    if (startDate != null && endDate != null) {
      final s = '${startDate.year}-${startDate.month.toString().padLeft(2,'0')}-${startDate.day.toString().padLeft(2,'0')}';
      final e = '${endDate.year}-${endDate.month.toString().padLeft(2,'0')}-${endDate.day.toString().padLeft(2,'0')}';
      query = '?startDate=$s&endDate=$e';
    }
    final response = await http.get(Uri.parse('$baseUrl/admin/reports/overtime$query'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load overtime report');
  }

  static Future<List<dynamic>> getSalaryHoursReport({DateTime? startDate, DateTime? endDate}) async {
    String query = '';
    if (startDate != null && endDate != null) {
      final s = '${startDate.year}-${startDate.month.toString().padLeft(2,'0')}-${startDate.day.toString().padLeft(2,'0')}';
      final e = '${endDate.year}-${endDate.month.toString().padLeft(2,'0')}-${endDate.day.toString().padLeft(2,'0')}';
      query = '?startDate=$s&endDate=$e';
    }
    final response = await http.get(Uri.parse('$baseUrl/admin/reports/salary-hours$query'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load salary hours report');
  }

  static Future<List<dynamic>> getPayrollReport({DateTime? startDate, DateTime? endDate}) async {
    String query = '';
    if (startDate != null && endDate != null) {
      final s = '${startDate.year}-${startDate.month.toString().padLeft(2,'0')}-${startDate.day.toString().padLeft(2,'0')}';
      final e = '${endDate.year}-${endDate.month.toString().padLeft(2,'0')}-${endDate.day.toString().padLeft(2,'0')}';
      query = '?startDate=$s&endDate=$e';
    }
    final response = await http.get(Uri.parse('$baseUrl/admin/reports/payroll$query'));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load payroll report');
  }
}
