import 'package:cached_network_image/cached_network_image.dart';
// --- 3. The Attendance Monitor ---
// This screen allows the Admin to see exactly who is in the office, who is late,
// and who hasn't shown up yet. It also supports exporting data for payroll.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/theme/pulse_colors.dart';
import 'package:frontend/core/theme/pulse_text_styles.dart';
import 'package:frontend/core/widgets/pulse_card.dart';
import 'package:frontend/core/widgets/pulse_shimmer.dart';
import 'package:frontend/core/widgets/pulse_empty_state.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/services/pdf_service.dart';
import 'package:frontend/core/services/csv_service.dart';

class AdminAttendanceScreen extends StatefulWidget {
  final bool isTab;
  const AdminAttendanceScreen({super.key, this.isTab = false});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  List<dynamic> _attendance = [];
  List<dynamic> _filteredAttendance = [];
  List<dynamic> _allEmployees = [];
  List<dynamic> _holidays = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadAttendance();
    _loadHolidays();
    try {
      final employees = await ApiService.getAllUsers();
      if (mounted) setState(() => _allEmployees = employees);
    } catch (_) {}
  }

  Future<void> _loadHolidays() async {
    try {
      final holidays = await ApiService.getHolidays();
      if (mounted) setState(() => _holidays = holidays);
    } catch (_) {}
  }

  // Fetch attendance for the selected date
  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    try {
      // We pass the same date as both start and end to get records for a SINGLE day
      final data = await ApiService.getAllAttendance(startDate: _selectedDate, endDate: _selectedDate);
      if (mounted) setState(() { _attendance = data; _applyFilter(); });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Locally search the fetched list by name or department (Instant UI update)
  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAttendance = _attendance.where((r) {
        final name = (r['fullName'] ?? '').toString().toLowerCase();
        final dept = (r['department'] ?? '').toString().toLowerCase();
        return name.contains(query) || dept.contains(query);
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDate,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: _loadAttendance,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Search employee or department…', prefixIcon: Icon(Icons.search)),
              onChanged: (_) => _applyFilter(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Holiday Banner (if selected date is a holiday)
                Builder(builder: (ctx) {
                  final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
                  final holiday = _holidays.firstWhere((h) => h['date'] == dateStr, orElse: () => null);
                  if (holiday == null) return const SizedBox.shrink();
                  
                  final isPublic = holiday['type'] == 'Public';
                  final color = isPublic ? PulseColors.success : PulseColors.accent;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: PulseCard(
                      color: color.withOpacity(0.1),
                      borderColor: color.withOpacity(0.3),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Text('🎉', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${DateFormat('MMM d').format(_selectedDate)} is ${holiday['name']}',
                              style: PulseTextStyles.bodyBold.copyWith(color: color, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                            child: Text(holiday['type'].toString().toUpperCase(), style: PulseTextStyles.captionBold.copyWith(color: color, fontSize: 8)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('EEE, MMM d, yyyy').format(_selectedDate), style: PulseTextStyles.bodyBold.copyWith(color: PulseColors.primary)),
                    Text('${_filteredAttendance.length} records', style: PulseTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: PulseShimmer.list(count: 4, itemHeight: 120))
                : _filteredAttendance.isEmpty
                    ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                        SizedBox(height: 60),
                        PulseEmptyState(icon: Icons.history_toggle_off, title: 'No Records', subtitle: 'No attendance for this date'),
                      ])
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _filteredAttendance.length,
                        itemExtent: 180.0, // Increased height to accommodate addresses
                        itemBuilder: (context, index) => _buildCard(_filteredAttendance[index]),
                      ),
          ),
        ],
      ),
    );

    if (widget.isTab) return content;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          // Filter by Date
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _selectDate(context)),
          // Add attendance manually (forgotten check-ins)
          IconButton(icon: const Icon(Icons.add_task), onPressed: _showManualEntryDialog, tooltip: 'Manual Entry'),
          // Export PDF report
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => PdfService.generateAdminAttendanceReport(_filteredAttendance), tooltip: 'PDF'),
          // Export CSV (Excel) for Payroll
          IconButton(
            icon: const Icon(Icons.download), tooltip: 'CSV',
            onPressed: () {
              CsvService.exportToCsv(
                'Attendance_${DateTime.now().millisecondsSinceEpoch}',
                ['Employee', 'Date', 'In', 'Out', 'Status', 'Location'],
                _filteredAttendance.map((r) => [
                  r['fullName'],
                  DateFormat('yyyy-MM-dd').format(DateTime.parse(r['checkInTime']).toLocal()),
                  DateFormat('hh:mm a').format(DateTime.parse(r['checkInTime']).toLocal()),
                  r['checkOutTime'] != null ? DateFormat('hh:mm a').format(DateTime.parse(r['checkOutTime']).toLocal()) : '-',
                  r['status'], r['checkInAddress'] ?? '-'
                ]).toList(),
              );
            },
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildCard(Map<String, dynamic> record) {
    final checkIn = DateTime.parse(record['checkInTime']).toLocal();
    final checkOut = record['checkOutTime'] != null ? DateTime.parse(record['checkOutTime']).toLocal() : null;
    final isLate = record['status'] == 'Late';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PulseCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(children: [
              CircleAvatar(
                radius: 20, backgroundColor: PulseColors.surfaceVariant,
                backgroundImage: record['profilePicture'] != null ? CachedNetworkImageProvider(ApiService.getImageUrl(record['profilePicture'])) : null,
                child: record['profilePicture'] == null ? const Icon(Icons.person, size: 20, color: PulseColors.textHint) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(record['fullName'] ?? 'Unknown', style: PulseTextStyles.bodyBold),
                Text(record['department'] ?? 'General', style: PulseTextStyles.caption.copyWith(fontSize: 11)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isLate ? PulseColors.error : PulseColors.success).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(record['status'] ?? 'On Time', style: PulseTextStyles.captionBold.copyWith(color: isLate ? PulseColors.error : PulseColors.success, fontSize: 10)),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _editAttendanceRecord(record),
                  child: Icon(Icons.edit_note, color: PulseColors.accent, size: 20),
                ),
              ]),
            ]),
            const SizedBox(height: 10),
            Divider(height: 1, color: PulseColors.border),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _timeCol('In', DateFormat('hh:mm a').format(checkIn), Icons.login, PulseColors.accent),
              _timeCol('Out', checkOut != null ? DateFormat('hh:mm a').format(checkOut) : '--:--', Icons.logout, PulseColors.warning),
              _timeCol('Hours', record['workHours']?.toStringAsFixed(1) ?? '0.0', Icons.work_outline, PulseColors.primary),
            ]),
            if (record['checkInAddress'] != null || record['checkOutAddress'] != null) ...[
              const SizedBox(height: 12),
              if (record['checkInAddress'] != null)
                _locationRow('In:', record['checkInAddress']),
              if (record['checkOutAddress'] != null) ...[
                const SizedBox(height: 4),
                _locationRow('Out:', record['checkOutAddress']),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _locationRow(String label, String address) {
    return Row(
      children: [
        SizedBox(
          width: 25,
          child: Text(label, style: PulseTextStyles.captionBold.copyWith(fontSize: 10, color: PulseColors.primary)),
        ),
        const Icon(Icons.location_on, size: 12, color: PulseColors.textHint),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            address,
            style: PulseTextStyles.caption.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _timeCol(String label, String time, IconData icon, Color color) {
    return Column(children: [
      Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: PulseTextStyles.caption.copyWith(fontSize: 10)),
      ]),
      const SizedBox(height: 3),
      Text(time, style: PulseTextStyles.bodyBold.copyWith(fontSize: 13)),
    ]);
  }

  // Opens a form to add a completely new attendance record (Manual Override)
  Future<void> _showManualEntryDialog() async {
    int? selectedEmployeeId;
    String status = 'Present';
    DateTime selectedTime = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Manual Attendance'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // List of all employees to choose from
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Select Employee'),
              items: _allEmployees.map((e) => DropdownMenuItem<int>(value: e['id'], child: Text(e['fullName']))).toList(),
              onChanged: (val) => selectedEmployeeId = val,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'Present', child: Text('Present')),
                DropdownMenuItem(value: 'Absent', child: Text('Absent')),
                DropdownMenuItem(value: 'Late', child: Text('Late')),
              ],
              onChanged: (val) => setDialogState(() => status = val!),
            ),
            const SizedBox(height: 16),
            // Pick exactly when they were "supposed" to check in
            ListTile(
              title: const Text('Date & Time'),
              subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(selectedTime)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: selectedTime, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (date != null) {
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedTime));
                  if (time != null) setDialogState(() => selectedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                }
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                if (selectedEmployeeId == null) return;
                try {
                  await ApiService.createManualAttendance({
                    'userId': selectedEmployeeId, 'status': status,
                    'checkInTime': selectedTime.toIso8601String(), 'address': 'Marked Manually by Admin',
                  });
                  if (context.mounted) Navigator.pop(context);
                  _loadAttendance();
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  // Fixes an existing record (e.g., if a user checked out too late by mistake)
  Future<void> _editAttendanceRecord(Map<String, dynamic> record) async {
    String status = record['status'] ?? 'Present';
    DateTime checkIn = DateTime.parse(record['checkInTime']);
    DateTime? checkOut = record['checkOutTime'] != null ? DateTime.parse(record['checkOutTime']) : null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: Text('Edit: ${record['fullName']}'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: status, decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'Present', child: Text('Present')),
                DropdownMenuItem(value: 'Absent', child: Text('Absent')),
                DropdownMenuItem(value: 'Late', child: Text('Late')),
              ],
              onChanged: (v) => setD(() => status = v!),
            ),
            const SizedBox(height: 16),
            // Edit In-time
            ListTile(
              title: const Text('Check In Time'), subtitle: Text(DateFormat('hh:mm a').format(checkIn)),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(checkIn));
                if (t != null) setD(() => checkIn = DateTime(checkIn.year, checkIn.month, checkIn.day, t.hour, t.minute));
              },
            ),
            // Edit Out-time
            ListTile(
              title: const Text('Check Out Time'), subtitle: Text(checkOut != null ? DateFormat('hh:mm a').format(checkOut!) : 'Not checked out'),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(checkOut ?? DateTime.now()));
                if (t != null) setD(() => checkOut = DateTime(checkIn.year, checkIn.month, checkIn.day, t.hour, t.minute));
              },
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.updateAttendance(record['id'], {
                    'status': status, 'checkInTime': checkIn.toIso8601String(), 'checkOutTime': checkOut?.toIso8601String(),
                  });
                  if (context.mounted) Navigator.pop(context);
                  _loadAttendance();
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }
}
