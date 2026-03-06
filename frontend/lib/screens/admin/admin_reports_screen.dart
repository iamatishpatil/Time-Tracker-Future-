// --- 8. The Monthly Analytics Screen ---
// This screen doesn't just show records; it calculates totals. It looks at the
// whole month and tells the Admin how many days each person was Present or Late.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';
import '../../core/widgets/pulse_shimmer.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _isLoading = true;
  List<dynamic> _employees = [];
  List<dynamic> _attendance = [];
  List<dynamic> _holidays = [];
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final employees = await ApiService.getAllUsers();
      
      final attendance = await ApiService.getAllAttendance(
        startDate: _selectedRange.start,
        endDate: _selectedRange.end,
      );
      
      final holidays = await ApiService.getHolidays();
      if (mounted) setState(() { _employees = employees; _attendance = attendance; _holidays = holidays; _isLoading = false; });
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    }
  }

  // --- The Brains: Stats Calculation ---
  Map<String, dynamic> _calculateRangeStats(String userId) {
    int present = 0, late = 0, halfDays = 0, holidaysCount = 0;

    // 1. Count scheduled public holidays in this range
    for (var h in _holidays) {
      final hDate = DateTime.parse(h['date']);
      if (hDate.isAfter(_selectedRange.start.subtract(const Duration(days: 1))) && 
          hDate.isBefore(_selectedRange.end.add(const Duration(days: 1))) && 
          h['type'] == 'Public') {
        holidaysCount++;
      }
    }

    // 2. Count actual "Punch-ins" for the user
    for (var record in _attendance) {
      if (record['userId'].toString() != userId.toString()) continue;
      final date = DateTime.parse(record['checkInTime']);
      if (date.isAfter(_selectedRange.start.subtract(const Duration(days: 1))) && 
          date.isBefore(_selectedRange.end.add(const Duration(days: 1)))) {
        present++;
        if (record['status'] == 'Late') late++;
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final holiday = _holidays.firstWhere((h) => h['date'] == dateStr, orElse: () => null);
        if (holiday != null && holiday['duration'] == 'Half Day') halfDays++;
      }
    }

    return {'present': present, 'late': late, 'holidays': holidaysCount, 'halfDayWork': halfDays};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _selectedRange,
              );
              if (picked != null) {
                setState(() => _selectedRange = picked);
                _loadData();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Padding(padding: const EdgeInsets.all(20), child: PulseShimmer.list(count: 4, itemHeight: 100))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${DateFormat('MMM d, yyyy').format(_selectedRange.start)} - ${DateFormat('MMM d, yyyy').format(_selectedRange.end)}',
                    style: PulseTextStyles.h3.copyWith(color: PulseColors.primary),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      final emp = _employees[index];
                      final stats = _calculateRangeStats(emp['id'].toString());
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PulseCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(children: [
                            Row(children: [
                              CircleAvatar(
                                radius: 20, backgroundColor: PulseColors.primary.withValues(alpha: 0.2),
                                child: Text(emp['fullName'][0], style: PulseTextStyles.bodyBold.copyWith(color: PulseColors.primary)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(emp['fullName'], style: PulseTextStyles.bodyBold),
                                Text(emp['designation'] ?? 'Employee', style: PulseTextStyles.caption.copyWith(fontSize: 11)),
                              ])),
                              IconButton(
                                icon: Icon(Icons.picture_as_pdf, color: PulseColors.error, size: 20),
                                onPressed: () {
                                  // Filter attendance for ONLY this employee AND within the selected range
                                  final userAttendance = _attendance.where((r) {
                                    final d = DateTime.parse(r['checkInTime']);
                                    return r['userId'].toString() == emp['id'].toString() &&
                                        d.isAfter(_selectedRange.start.subtract(const Duration(days: 1))) &&
                                        d.isBefore(_selectedRange.end.add(const Duration(days: 1)));
                                  }).toList();
                                  
                                  PdfService.generateAttendanceReport(
                                    emp['fullName'], 
                                    userAttendance, 
                                    holidays: _holidays
                                  );
                                },
                              ),
                            ]),
                            Divider(height: 20, color: PulseColors.border),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                              _miniStat('Present', stats['present'].toString(), PulseColors.success),
                              _miniStat('Late', stats['late'].toString(), PulseColors.warning),
                              _miniStat('Holidays', stats['holidays'].toString(), PulseColors.accent),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: PulseTextStyles.h3.copyWith(color: color, fontSize: 18)),
      Text(label, style: PulseTextStyles.caption.copyWith(fontSize: 10)),
    ]);
  }
}
