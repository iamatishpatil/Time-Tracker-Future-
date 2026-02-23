// --- 5. The Payroll & Finance Screen ---
// This is the most complex Admin module. It calculates exactly how much
// to pay each employee based on their worked hours, late entries, and overtime.

import 'package:flutter/material.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';
import '../../core/widgets/pulse_shimmer.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../services/csv_service.dart';

class AdminPayrollScreen extends StatefulWidget {
  const AdminPayrollScreen({super.key});

  @override
  State<AdminPayrollScreen> createState() => _AdminPayrollScreenState();
}

class _AdminPayrollScreenState extends State<AdminPayrollScreen> {
  List<dynamic> _payroll = [];
  List<dynamic> _overtime = [];
  List<dynamic> _salaryHours = [];
  bool _isLoading = true;
  int _tabIndex = 0;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Fetch payroll data for the selected period (e.g., this month)
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // We fetch 3 different perspectives from the server:
      // 1. Full Payroll (Money)
      final payroll = await ApiService.getPayrollReport(startDate: _dateRange?.start, endDate: _dateRange?.end);
      // 2. Overtime focus (Extra hours)
      final overtime = await ApiService.getOvertimeReport(startDate: _dateRange?.start, endDate: _dateRange?.end);
      // 3. Raw Hours audit (Basic attendance stats)
      final salaryHours = await ApiService.getSalaryHoursReport(startDate: _dateRange?.start, endDate: _dateRange?.end);
      
      if (mounted) setState(() { _payroll = payroll; _overtime = overtime; _salaryHours = salaryHours; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now(), initialDateRange: _dateRange);
    if (range != null) { setState(() => _dateRange = range); _loadData(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll'),
        actions: [
          IconButton(icon: const Icon(Icons.date_range), onPressed: _pickDateRange, tooltip: 'Filter'),
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => PdfService.generatePayrollReport(_payroll), tooltip: 'PDF'),
          IconButton(
            icon: const Icon(Icons.download), tooltip: 'CSV',
            onPressed: () {
              CsvService.exportToCsv(
                'Payroll_${DateTime.now().millisecondsSinceEpoch}',
                ['Employee', 'Base Salary', 'Working Days', 'Worked Hours', 'OT Pay', 'Late Penalties', 'Net Salary'],
                _payroll.map((r) => [r['fullName'], r['salary'], r['workingDays'] ?? 22, r['totalHours'], r['overtimePay'], r['latePenalty'], r['netSalary']]).toList(),
              );
            },
          ),
          if (_dateRange != null) IconButton(icon: const Icon(Icons.clear), onPressed: () { setState(() => _dateRange = null); _loadData(); }),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            decoration: BoxDecoration(
              color: PulseColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              _tab('Payroll', 0),
              _tab('Overtime', 1),
              _tab('Hours', 2),
            ]),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _isLoading
                  ? Padding(padding: const EdgeInsets.all(14), child: PulseShimmer.list(count: 4, itemHeight: 100))
                  : _tabIndex == 0 ? _buildPayrollTab()
                      : _tabIndex == 1 ? _buildOvertimeTab()
                      : _buildHoursTab(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, int index) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? PulseColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: PulseTextStyles.captionBold.copyWith(color: selected ? Colors.white : PulseColors.textSecondary)),
        ),
      ),
    );
  }

  // --- TAB 1: The Money View ---
  Widget _buildPayrollTab() {
    if (_payroll.isEmpty) return const Center(child: Text('No payroll data', style: TextStyle(color: PulseColors.textHint)));
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _payroll.length,
      itemBuilder: (ctx, i) {
        final p = _payroll[i];
        final net = double.tryParse(p['netSalary'].toString()) ?? 0;
        final base = (p['salary'] as num?)?.toDouble() ?? 0;
        final ot = double.tryParse(p['overtimePay'].toString()) ?? 0;
        final penalty = double.tryParse(p['latePenalty'].toString()) ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PulseCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['fullName'] ?? 'Unknown', style: PulseTextStyles.bodyBold),
              Divider(height: 16, color: PulseColors.border),
              _payRow('Base Salary', '₹${base.toStringAsFixed(0)}', PulseColors.accent),
              _payRow('Overtime (+)', '₹${ot.toStringAsFixed(2)}', PulseColors.success),
              _payRow('Late Penalty (-)', '₹${penalty.toStringAsFixed(2)}', PulseColors.error),
              Divider(height: 16, color: PulseColors.border),
              // THE BOTTOM LINE: What they actually get in the bank
              _payRow('Net Salary', '₹${net.toStringAsFixed(2)}', PulseColors.primary, bold: true),
              const SizedBox(height: 4),
              // Footnote showing the raw data behind the numbers
              Text('Days: ${p['workingDays'] ?? 22}  •  Hrs: ${(p['totalHours'] as num?)?.toStringAsFixed(1) ?? '0'}  •  OT: ${(p['totalOvertimeHours'] as num?)?.toStringAsFixed(1) ?? '0'}h  •  Late: ${p['lateDays'] ?? 0}d',
                  style: PulseTextStyles.caption.copyWith(fontSize: 10)),
            ]),
          ),
        );
      },
    );
  }

  Widget _payRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: bold ? PulseTextStyles.bodyBold : PulseTextStyles.body),
        Text(value, style: (bold ? PulseTextStyles.bodyBold : PulseTextStyles.body).copyWith(color: color)),
      ]),
    );
  }

  // --- TAB 2: The Overtime Audit ---
  Widget _buildOvertimeTab() {
    if (_overtime.isEmpty) return const Center(child: Text('No overtime records', style: TextStyle(color: PulseColors.textHint)));
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _overtime.length,
      itemBuilder: (ctx, i) {
        final o = _overtime[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PulseCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: PulseColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.timer, color: PulseColors.warning, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o['fullName'] ?? 'Unknown', style: PulseTextStyles.bodyBold),
                Text('${o['overtimeDays']} overtime days', style: PulseTextStyles.caption),
              ])),
              // Shows total extra hours worked this month
              Text('${(o['totalOvertimeHours'] as num?)?.toStringAsFixed(1) ?? '0'}h',
                  style: PulseTextStyles.h3.copyWith(color: PulseColors.warning, fontSize: 18)),
            ]),
          ),
        );
      },
    );
  }

  // --- TAB 3: The Productivity Audit ---
  Widget _buildHoursTab() {
    if (_salaryHours.isEmpty) return const Center(child: Text('No hours data', style: TextStyle(color: PulseColors.textHint)));
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _salaryHours.length,
      itemBuilder: (ctx, i) {
        final s = _salaryHours[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PulseCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: PulseColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.access_time, color: PulseColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['fullName'] ?? 'Unknown', style: PulseTextStyles.bodyBold),
                Text('Late: ${s['lateDays'] ?? 0}d  •  OT: ${(s['totalOvertimeHours'] as num?)?.toStringAsFixed(1) ?? '0'}h', style: PulseTextStyles.caption),
              ])),
              // Shows total working hours (Base + OT)
              Text('${(s['totalHours'] as num?)?.toStringAsFixed(1) ?? '0'}h',
                  style: PulseTextStyles.h3.copyWith(color: PulseColors.accent, fontSize: 18)),
            ]),
          ),
        );
      },
    );
  }
}
