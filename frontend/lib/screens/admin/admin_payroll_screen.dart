import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/pdf_service.dart';
import '../../services/csv_service.dart';
import '../../widgets/common/glass_card.dart';

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final payroll = await ApiService.getPayrollReport(
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );
      final overtime = await ApiService.getOvertimeReport(
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );
      final salaryHours = await ApiService.getSalaryHoursReport(
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );
      if (mounted) setState(() { _payroll = payroll; _overtime = overtime; _salaryHours = salaryHours; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (range != null) {
      setState(() => _dateRange = range);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll & Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
            tooltip: 'Filter by Date',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => PdfService.generatePayrollReport(_payroll),
            tooltip: 'Export PDF',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              CsvService.exportToCsv(
                'Payroll_Report_${DateTime.now().millisecondsSinceEpoch}',
                ['Employee', 'Base Salary', 'Worked Hours', 'OT Pay', 'Late Penalties', 'Net Salary'],
                _payroll.map((r) => [
                  r['fullName'],
                  r['salary'],
                  r['totalHours'],
                  r['overtimePay'],
                  r['latePenalty'],
                  r['netSalary']
                ]).toList()
              );
            },
            tooltip: 'Export CSV',
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () { setState(() => _dateRange = null); _loadData(); },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _tab('Payroll', 0),
              _tab('Overtime', 1),
              _tab('Hours', 2),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tabIndex == 0
              ? _buildPayrollTab()
              : _tabIndex == 1
                  ? _buildOvertimeTab()
                  : _buildHoursTab(),
    );
  }

  Widget _tab(String label, int index) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
              color: selected ? Colors.white : Colors.transparent,
              width: 3,
            )),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white60,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPayrollTab() {
    if (_payroll.isEmpty) return const Center(child: Text('No payroll data available'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payroll.length,
      itemBuilder: (ctx, i) {
        final p = _payroll[i];
        final netSalary = double.tryParse(p['netSalary'].toString()) ?? 0;
        final baseSalary = (p['salary'] as num?)?.toDouble() ?? 0;
        final overtimePay = double.tryParse(p['overtimePay'].toString()) ?? 0;
        final latePenalty = double.tryParse(p['latePenalty'].toString()) ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['fullName'] ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(),
                _payrollRow('Base Salary', '₹${baseSalary.toStringAsFixed(0)}', Colors.blue),
                _payrollRow('Overtime Pay (+)', '₹${overtimePay.toStringAsFixed(2)}', Colors.green),
                _payrollRow('Late Penalty (-)', '₹${latePenalty.toStringAsFixed(2)}', Colors.red),
                const Divider(),
                _payrollRow('Net Salary', '₹${netSalary.toStringAsFixed(2)}', Colors.deepPurple, bold: true),
                const SizedBox(height: 4),
                Text('Hours: ${(p['totalHours'] as num?)?.toStringAsFixed(1) ?? '0'}h  |  OT: ${(p['totalOvertimeHours'] as num?)?.toStringAsFixed(1) ?? '0'}h  |  Late: ${p['lateDays'] ?? 0} days',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _payrollRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildOvertimeTab() {
    if (_overtime.isEmpty) return const Center(child: Text('No overtime records found'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _overtime.length,
      itemBuilder: (ctx, i) {
        final o = _overtime[i];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3E0), child: Icon(Icons.timer, color: Colors.orange)),
            title: Text(o['fullName'] ?? 'Unknown'),
            subtitle: Text('${o['overtimeDays']} overtime days'),
            trailing: Text(
              '${(o['totalOvertimeHours'] as num?)?.toStringAsFixed(1) ?? '0'}h',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHoursTab() {
    if (_salaryHours.isEmpty) return const Center(child: Text('No hours data found'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _salaryHours.length,
      itemBuilder: (ctx, i) {
        final s = _salaryHours[i];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.access_time, color: Colors.blue)),
            title: Text(s['fullName'] ?? 'Unknown'),
            subtitle: Text('Late: ${s['lateDays'] ?? 0} days  |  OT: ${(s['totalOvertimeHours'] as num?)?.toStringAsFixed(1) ?? '0'}h'),
            trailing: Text(
              '${(s['totalHours'] as num?)?.toStringAsFixed(1) ?? '0'}h',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
        );
      },
    );
  }
}
