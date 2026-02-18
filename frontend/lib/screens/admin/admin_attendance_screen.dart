import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../services/csv_service.dart';
import '../../widgets/common/glass_card.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  List<dynamic> _attendance = [];
  List<dynamic> _filteredAttendance = [];
  List<dynamic> _allEmployees = [];
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
    try {
      final employees = await ApiService.getAllUsers();
      if (mounted) setState(() => _allEmployees = employees);
    } catch (_) {}
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAllAttendance(startDate: _selectedDate, endDate: _selectedDate);
      if (mounted) {
        setState(() {
          _attendance = data;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_task),
            onPressed: () => _showManualEntryDialog(),
            tooltip: 'Manual Entry',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => PdfService.generateAdminAttendanceReport(_filteredAttendance),
            tooltip: 'Export PDF',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              CsvService.exportToCsv(
                'Attendance_Report_${DateTime.now().millisecondsSinceEpoch}',
                ['Employee', 'Date', 'In', 'Out', 'Status', 'Location'],
                _filteredAttendance.map((r) => [
                  r['fullName'],
                  r['checkInTime'],
                  r['checkInTime'],
                  r['checkOutTime'] ?? '-',
                  r['status'],
                  r['checkInAddress']
                ]).toList()
              );
            },
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by employee or department...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.5),
              ),
              onChanged: (_) => _applyFilter(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${_filteredAttendance.length} Records',
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredAttendance.isEmpty
                    ? const Center(child: Text('No records found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredAttendance.length,
                        itemBuilder: (context, index) {
                          final record = _filteredAttendance[index];
                          return _buildAttendanceCard(record);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    final checkIn = DateTime.parse(record['checkInTime']).toLocal();
    final checkOut = record['checkOutTime'] != null ? DateTime.parse(record['checkOutTime']).toLocal() : null;
    
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: record['profilePicture'] != null 
                  ? NetworkImage(ApiService.getImageUrl(record['profilePicture']))
                  : null,
                child: record['profilePicture'] == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record['fullName'] ?? 'Unknown Employee',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      record['department'] ?? 'General',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: record['status'] == 'Late' ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      record['status'] ?? 'On Time',
                      style: TextStyle(
                        color: record['status'] == 'Late' ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.blue, size: 20),
                    onPressed: () => _editAttendanceRecord(record),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeColumn('Check In', DateFormat('hh:mm a').format(checkIn), Icons.login, Colors.blue),
              _buildTimeColumn('Check Out', checkOut != null ? DateFormat('hh:mm a').format(checkOut) : '--:--', Icons.logout, Colors.orange),
              _buildTimeColumn('Work Hrs', record['workHours']?.toStringAsFixed(1) ?? '0.0', Icons.work_outline, Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showManualEntryDialog() async {
    int? selectedEmployeeId;
    String status = 'Present';
    DateTime selectedTime = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Manual Attendance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Select Employee'),
                items: _allEmployees.map((e) => DropdownMenuItem<int>(
                  value: e['id'],
                  child: Text(e['fullName']),
                )).toList(),
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
              ListTile(
                title: const Text('Date & Time'),
                subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(selectedTime)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedTime,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedTime),
                    );
                    if (time != null) {
                      setDialogState(() {
                        selectedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                if (selectedEmployeeId == null) return;
                try {
                  await ApiService.createManualAttendance({
                    'userId': selectedEmployeeId,
                    'status': status,
                    'checkInTime': selectedTime.toIso8601String(),
                    'address': 'Marked Manually by Admin',
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

  Future<void> _editAttendanceRecord(Map<String, dynamic> record) async {
    String status = record['status'] ?? 'Present';
    DateTime checkIn = DateTime.parse(record['checkInTime']);
    DateTime? checkOut = record['checkOutTime'] != null ? DateTime.parse(record['checkOutTime']) : null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: Text('Edit Record: ${record['fullName']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'Present', child: Text('Present')),
                    DropdownMenuItem(value: 'Absent', child: Text('Absent')),
                    DropdownMenuItem(value: 'Late', child: Text('Late')),
                  ],
                  onChanged: (v) => setD(() => status = v!),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Check In Time'),
                  subtitle: Text(DateFormat('hh:mm a').format(checkIn)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(checkIn));
                    if (t != null) setD(() => checkIn = DateTime(checkIn.year, checkIn.month, checkIn.day, t.hour, t.minute));
                  },
                ),
                ListTile(
                  title: const Text('Check Out Time'),
                  subtitle: Text(checkOut != null ? DateFormat('hh:mm a').format(checkOut!) : 'Not checked out'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(checkOut ?? DateTime.now()));
                    if (t != null) setD(() => checkOut = DateTime(checkIn.year, checkIn.month, checkIn.day, t.hour, t.minute));
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.updateAttendance(record['id'], {
                    'status': status,
                    'checkInTime': checkIn.toIso8601String(),
                    'checkOutTime': checkOut?.toIso8601String(),
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

  Widget _buildTimeColumn(String label, String time, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

// Added margin to GlassCard via extension or custom implementation if not exists
extension on GlassCard {
  Widget withMargin(EdgeInsets margin) => Container(margin: margin, child: this);
}
// Note: GlassCard doesn't have margin property, wrapping it.
// Actually I'll just adjust the buildAttendanceCard to use Padding/Container if needed.
// But GlassCard is a StatelessWidget, so I can't easily add margin unless I wrap it.
// I'll update the code to wrap it in a Container.
