import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import 'admin_map_screen.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  List<dynamic> _attendance = [];
  List<dynamic> _filteredAttendance = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAllAttendance();
      if (mounted) {
        setState(() {
          _attendance = data;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredAttendance = _attendance.where((record) {
        final name = (record['fullName'] ?? '').toString().toLowerCase();
        final query = _searchController.text.toLowerCase();
        final matchesName = name.contains(query);

        final checkIn = DateTime.parse(record['checkInTime']).toLocal();
        final matchesDate = _selectedDate == null || 
            (checkIn.year == _selectedDate!.year && 
             checkIn.month == _selectedDate!.month && 
             checkIn.day == _selectedDate!.day);

        return matchesName && matchesDate;
      }).toList();
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Attendance'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: _selectedDate != null ? Colors.blue : null),
            onPressed: _selectDate,
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() => _selectedDate = null);
                _applyFilters();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by employee name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (_) => _applyFilters(),
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredAttendance.isEmpty
                    ? const Center(child: Text('No attendance records found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredAttendance.length,
                        itemBuilder: (context, index) {
                          final record = _filteredAttendance[index];
                          final checkIn = DateTime.parse(record['checkInTime']).toLocal();
                          final checkOut = record['checkOutTime'] != null ? DateTime.parse(record['checkOutTime']).toLocal() : null;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage: record['profilePicture'] != null 
                                            ? NetworkImage('http://192.168.1.33:3000${record['profilePicture']}')
                                            : null,
                                        child: record['profilePicture'] == null ? const Icon(Icons.person) : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(record['fullName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text(DateFormat('MMM d, y').format(checkIn), style: TextStyle(color: Colors.grey[600])),
                                        ],
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: checkOut == null ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          checkOut == null ? 'Active' : 'Completed',
                                          style: TextStyle(
                                            color: checkOut == null ? Colors.green : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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
                                            Text(DateFormat('hh:mm a').format(checkIn), style: const TextStyle(fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            if (record['checkInPhoto'] != null)
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  'http://192.168.1.33:3000${record['checkInPhoto']}',
                                                  height: 60,
                                                  width: 60,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image),
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
                                              Text(DateFormat('hh:mm a').format(checkOut), style: const TextStyle(fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              if (record['checkOutPhoto'] != null)
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    'http://192.168.1.33:3000${record['checkOutPhoto']}',
                                                    height: 60,
                                                    width: 60,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (record['lat'] != null && record['long'] != null) ...[
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AdminMapScreen(
                                              latitude: double.parse(record['lat'].toString()),
                                              longitude: double.parse(record['long'].toString()),
                                              title: '${record['fullName']} Location',
                                              address: record['checkInAddress'] ?? 'No address captured',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.map, size: 18),
                                      label: const Text('VIEW ON MAP'),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
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
