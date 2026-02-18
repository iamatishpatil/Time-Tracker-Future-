import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final user = await ApiService.getStoredUser();
      if (user != null) {
        _userName = user['fullName'] ?? 'User';
        final history = await ApiService.getAttendance(user['id']);
        if (mounted) setState(() => _history = history);
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3E5F5),
      child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // User Details Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6200EA), Color(0xFF651FFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6200EA).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_history.length} ${_history.length == 1 ? 'Record' : 'Records'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Attendance List
                Expanded(
                  child: _history.isEmpty 
                      ? const Center(child: Text('No attendance records found'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final record = _history[index];
                            final checkIn = DateTime.parse(record['checkInTime']).toLocal();
                            final checkOut = record['checkOutTime'] != null ? DateTime.parse(record['checkOutTime']).toLocal() : null;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat('EEEE, MMM d').format(checkIn),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6200EA)),
                                        ),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: checkOut == null ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                checkOut == null ? 'Active' : 'Completed',
                                                style: TextStyle(
                                                  color: checkOut == null ? Colors.orange : Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            if (record['status'] == 'Late') ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'LATE',
                                                  style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                            if (record['overtimeHours'] != null && (record['overtimeHours'] is num) && record['overtimeHours'] > 0) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '+${(record['overtimeHours'] as num).toStringAsFixed(1)} HRS',
                                                  style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Check In', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                              const SizedBox(height: 4),
                                              Text(DateFormat('hh:mm a').format(checkIn), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              const SizedBox(height: 8),
                                              if (record['checkInPhoto'] != null)
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    ApiService.getImageUrl(record['checkInPhoto']),
                                                    height: 80,
                                                    width: 80,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (checkOut != null)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Check Out', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                                const SizedBox(height: 4),
                                                Text(DateFormat('hh:mm a').format(checkOut), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                const SizedBox(height: 8),
                                                if (record['checkOutPhoto'] != null)
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.network(
                                                      ApiService.getImageUrl(record['checkOutPhoto']),
                                                      height: 80,
                                                      width: 80,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (record['checkInAddress'] != null) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(record['checkInAddress'], style: const TextStyle(color: Colors.grey, fontSize: 12))),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
