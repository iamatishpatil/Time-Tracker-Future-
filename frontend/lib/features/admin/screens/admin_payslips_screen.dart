// --- 6. The Payslip Manager ---
// This screen allows Admins to officially "Publish" a salary record for an employee.
// Once generated here, the employee will see it in their "My Payslips" screen.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/theme/pulse_colors.dart';
import 'package:frontend/core/theme/pulse_text_styles.dart';
import 'package:frontend/core/widgets/pulse_card.dart';
import 'package:frontend/core/widgets/pulse_shimmer.dart';
import 'package:frontend/core/widgets/pulse_button.dart';
import 'package:frontend/core/services/api_service.dart';

class AdminPayslipsScreen extends StatefulWidget {
  const AdminPayslipsScreen({super.key});

  @override
  State<AdminPayslipsScreen> createState() => _AdminPayslipsScreenState();
}

class _AdminPayslipsScreenState extends State<AdminPayslipsScreen> {
  List<dynamic> _payslips = [];
  bool _isLoading = true;
  bool _isPayrollEnabled = true;
  List<dynamic> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadPayslips();
  }

  Future<void> _loadPayslips() async {
    setState(() => _isLoading = true);
    try {
      final payslips = await ApiService.getAdminPayslips();
      final settings = await ApiService.getSettings();
      final users = await ApiService.getAllUsers();
      if (mounted) {
        setState(() {
          _payslips = payslips;
          _employees = users;
          _isPayrollEnabled = settings['payrollEnabled'] != 0;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePayslip(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payslip'),
        content: const Text('Are you sure you want to delete this payslip? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: PulseColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deletePayslip(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Payslip deleted.'),
          backgroundColor: PulseColors.success,
        ));
        }
        _loadPayslips();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddPayslipSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PulseColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _AddPayslipSheet(),
    ).then((val) {
      if (val == true) _loadPayslips();
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- FEATURE GATE ---
    // If the Boss turned off Payroll in settings, we block access to this screen entirely.
    if (!_isPayrollEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Payslips')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: PulseColors.textHint),
              const SizedBox(height: 16),
              Text('Payroll Feature Disabled', style: PulseTextStyles.h3),
              const SizedBox(height: 8),
              Text('Enable this feature in Admin Settings to continue.', style: PulseTextStyles.caption),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Payslips')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: PulseColors.primary,
        icon: const Icon(Icons.add_card, color: Colors.white),
        label: const Text('Generate Payslip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddPayslipSheet,
      ),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PulseShimmer.list(count: 5, itemHeight: 90),
            )
          : _payslips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.request_quote_outlined, size: 80, color: PulseColors.border),
                      const SizedBox(height: 16),
                      Text('No payslips generated yet', style: PulseTextStyles.h3),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                  itemCount: _payslips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _payslips[index];
                    final date = DateTime(item['year'], item['month']);
                    final netSalaryStr = '₹${item['netSalary'].toString()}';
                    
                    return PulseCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: PulseColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.description, color: PulseColors.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['fullName']}', style: PulseTextStyles.bodyBold),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 14, color: PulseColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('MMMM yyyy').format(date), 
                                      style: PulseTextStyles.caption.copyWith(color: PulseColors.textSecondary)
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(netSalaryStr, style: PulseTextStyles.h3.copyWith(color: PulseColors.success)),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => _deletePayslip(item['id']),
                                child: Text('Delete', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.error)),
                              )
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1);
                  },
                ),
    );
  }
}

// This is the "Pop-up" form to create a new payslip
class _AddPayslipSheet extends StatefulWidget {
  const _AddPayslipSheet();

  @override
  State<_AddPayslipSheet> createState() => _AddPayslipSheetState();
}

class _AddPayslipSheetState extends State<_AddPayslipSheet> {
  List<dynamic> _employees = [];
  bool _isLoadingEmployees = true;
  bool _isSubmitting = false;

  int? _selectedUserId;
  double? _basicSalary;
  DateTime _selectedMonth = DateTime.now();

  final _allowancesCtrl = TextEditingController(text: '0');
  final _deductionsCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await ApiService.getAllUsers();
      // Auto select the first employee if list is not empty
      if (mounted) {
        setState(() {
          _employees = employees;
          if (_employees.isNotEmpty) {
            _selectedUserId = _employees.first['id'];
            _basicSalary = _employees.first['salary']?.toDouble() ?? 0.0;
          }
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingEmployees = false);
    }
  }

  void _onEmployeeChanged(int? userId) {
    if (userId == null) return;
    final emp = _employees.firstWhere((e) => e['id'] == userId);
    setState(() {
      _selectedUserId = userId;
      _basicSalary = emp['salary']?.toDouble() ?? 0.0;
    });
  }

  void _pickMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: PulseColors.primary,
              onPrimary: Colors.white,
              surface: PulseColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
      });
    }
  }

  // Calculate and Save the payslip
  Future<void> _submit() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an employee')));
      return;
    }

    final allowances = double.tryParse(_allowancesCtrl.text) ?? 0.0;
    final deductions = double.tryParse(_deductionsCtrl.text) ?? 0.0;
    // Formula: Basic + Extra - Taxes/Penalties
    final netSalary = (_basicSalary ?? 0) + allowances - deductions;

    setState(() => _isSubmitting = true);
    
    try {
      await ApiService.createPayslip({
        'userId': _selectedUserId,
        'month': _selectedMonth.month,
        'year': _selectedMonth.year,
        'basicSalary': _basicSalary,
        'allowances': allowances,
        'deductions': deductions,
        'netSalary': netSalary,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingEmployees) {
      return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
    }

    final netSalary = (_basicSalary ?? 0) + 
                      (double.tryParse(_allowancesCtrl.text) ?? 0) - 
                      (double.tryParse(_deductionsCtrl.text) ?? 0);

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Generate Payslip', style: PulseTextStyles.h3),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 20),
          
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Employee'),
            value: _selectedUserId,
            items: _employees.map((e) => DropdownMenuItem<int>(
              value: e['id'],
              child: Text(e['fullName'] ?? ''),
            )).toList(),
            onChanged: _onEmployeeChanged,
          ),
          const SizedBox(height: 16),
          
          InkWell(
            onTap: _pickMonth,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Salary Month & Year'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('MMMM yyyy').format(_selectedMonth)),
                  Icon(Icons.calendar_month, color: PulseColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Basic Salary (Monthly)'),
            child: Text('₹${_basicSalary?.toStringAsFixed(2) ?? '0.00'}', style: PulseTextStyles.bodyBold),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _allowancesCtrl,
                  decoration: const InputDecoration(labelText: 'Allowances (Bonus, etc)', prefixText: '₹ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setState((){}),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _deductionsCtrl,
                  decoration: const InputDecoration(labelText: 'Deductions (Taxes, etc)', prefixText: '₹ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setState((){}),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PulseColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PulseColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net Payable Salary:', style: PulseTextStyles.bodyBold),
                Text('₹${netSalary.toStringAsFixed(2)}', style: PulseTextStyles.h2.copyWith(color: PulseColors.primary)),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          PulseButton(
            text: 'Generate Payslip',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
