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
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final employees = await ApiService.getAllUsers();
      final attendance = await ApiService.getAllAttendance();
      final holidays = await ApiService.getHolidays();
      if (mounted) setState(() { _employees = employees; _attendance = attendance; _holidays = holidays; _isLoading = false; });
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    }
  }

  Map<String, dynamic> _calculateMonthlyStats(String userId) {
    int present = 0, late = 0, halfDays = 0, holidaysCount = 0;

    for (var h in _holidays) {
      final hDate = DateTime.parse(h['date']);
      if (hDate.year == _selectedMonth.year && hDate.month == _selectedMonth.month && h['type'] == 'Public') holidaysCount++;
    }

    for (var record in _attendance) {
      if (record['userId'].toString() != userId.toString()) continue;
      final date = DateTime.parse(record['checkInTime']);
      if (date.year == _selectedMonth.year && date.month == _selectedMonth.month) {
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
        title: const Text('Monthly Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final date = await showDatePicker(context: context, initialDate: _selectedMonth, firstDate: DateTime(2020), lastDate: DateTime(2030));
              if (date != null) setState(() => _selectedMonth = date);
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
                  child: Text(DateFormat('MMMM yyyy').format(_selectedMonth), style: PulseTextStyles.h2.copyWith(color: PulseColors.primary)),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      final emp = _employees[index];
                      final stats = _calculateMonthlyStats(emp['id'].toString());
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PulseCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(children: [
                            Row(children: [
                              CircleAvatar(
                                radius: 20, backgroundColor: PulseColors.primary.withOpacity(0.2),
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
                                  final userAttendance = _attendance.where((r) {
                                    final d = DateTime.parse(r['checkInTime']);
                                    return r['userId'].toString() == emp['id'].toString() &&
                                        d.year == _selectedMonth.year && d.month == _selectedMonth.month;
                                  }).toList();
                                  PdfService.generateAttendanceReport(emp['fullName'], userAttendance, holidays: _holidays);
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
