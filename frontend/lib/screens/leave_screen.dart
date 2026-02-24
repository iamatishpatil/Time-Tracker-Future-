// --- 1. The Leave Management Screen ---
// This is where users can see how many days off they have left and 
// request new leaves. It's a great example of a complex Form in Flutter.

import 'package:flutter/material.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../core/widgets/pulse_card.dart';
import '../core/widgets/pulse_button.dart';
import '../core/widgets/pulse_shimmer.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  // We use these to store the dates the user picks from the calendar
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();

  Map<String, dynamic> _balance = {'total': 30, 'used': 0, 'remaining': 30};
  List<dynamic> _history = [];
  List<dynamic> _holidays = [];
  bool _isLoading = true;
  String _selectedLeaveType = 'Casual Leave';
  final List<String> _leaveTypes = [
    'Sick Leave', 'Casual Leave', 'Earned Leave (Privilege)', 
    'Maternity Leave', 'Paternity Leave', 'Bereavement Leave', 
    'Compensatory Off (Comp-off)', 'Marriage Leave', 
    'Leave Without Pay (LWP)', 'Sabbatical Leave'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Fetch information about the user's leaves from the server
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await ApiService.getStoredUser();
      if (user != null) {
        // 1. Get how many days are Total, Used, and Left
        final balance = await ApiService.getLeaveBalance(user['id']);
        // 2. Short list of previous requests
        final history = await ApiService.getLeaveHistory(user['id']);
        // 3. The list of categories (Sick, Casual, etc)
        final types = await ApiService.getLeaveTypes();

        if (mounted) {
          setState(() {
            _balance = balance;
            _history = history;
            _leaveTypes.clear();
            _leaveTypes.addAll(types);
            if (!_leaveTypes.contains(_selectedLeaveType)) {
              _selectedLeaveType = _leaveTypes.isNotEmpty ? _leaveTypes[0] : 'Casual Leave';
            }
          });

          // Also get holidays so we can skip them during calculations
          final holidays = await ApiService.getHolidays();
          if (mounted) setState(() => _holidays = holidays);
        }
      }
    } catch (e) {
      debugPrint('Error loading leave data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRequest() async {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select dates')));
        return;
      }

      setState(() => _isLoading = true);
      try {
        final user = await ApiService.getStoredUser();
        await ApiService.applyLeave({
          'userId': user!['id'],
          'leaveType': _selectedLeaveType,
          'startDate': DateFormat('yyyy-MM-dd').format(_startDate!),
          'endDate': DateFormat('yyyy-MM-dd').format(_endDate!),
          'reason': _reasonController.text,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Leave request submitted!')));
          _reasonController.clear();
          setState(() {
            _startDate = null;
            _endDate = null;
          });
          _loadData();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelRequest(int leaveId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Leave?'),
        content: const Text('Are you sure you want to cancel this request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final user = await ApiService.getStoredUser();
        await ApiService.cancelLeave(leaveId, user!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave cancelled')));
          _loadData();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: PulseShimmer.list(count: 3, itemHeight: 80),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Cards
            Row(
              children: [
                _balanceCard('Accrued', _balance['total'].toString(), PulseColors.accent),
                const SizedBox(width: 8),
                _balanceCard('Used', _balance['used'].toString(), PulseColors.error),
                const SizedBox(width: 8),
                _balanceCard('Left', _balance['remaining'].toString(), PulseColors.success),
              ],
            ),
            const SizedBox(height: 24),

            Text('Apply for Leave', style: PulseTextStyles.h3),
            const SizedBox(height: 16),
            _buildRequestForm(),

            const SizedBox(height: 28),
            Text('Leave History', style: PulseTextStyles.h3),
            const SizedBox(height: 12),
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(String label, String value, Color color) {
    return Expanded(
      child: PulseCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(value, style: PulseTextStyles.h2.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(label, style: PulseTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedLeaveType,
            decoration: const InputDecoration(
              labelText: 'Leave Type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            dropdownColor: PulseColors.surfaceVariant,
            items: _leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _selectedLeaveType = v!),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _dateSelector('Start Date', _startDate, (date) => setState(() => _startDate = date)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dateSelector('End Date', _endDate, (date) => setState(() => _endDate = date),
                    firstDate: _startDate),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Holiday Logic (The Smart Part) ---
          // This section calculates exactly how many days will be deducted
          // by looping through the dates and skipping Sundays and Public Holidays.
          if (_startDate != null && _endDate != null) ...[
            PulseCard(
              color: PulseColors.accent.withOpacity(0.1),
              borderColor: PulseColors.accent.withOpacity(0.2),
              padding: const EdgeInsets.all(12),
              child: Builder(builder: (context) {
                double days = 0;
                int holidayCount = 0;
                DateTime current = _startDate!;
                final end = _endDate!.add(const Duration(days: 1));

                while (current.isBefore(end)) {
                  final dateStr = DateFormat('yyyy-MM-dd').format(current);
                  // Check if THIS date is in our list of holidays from the server
                  final holiday = _holidays.firstWhere((h) => h['date'] == dateStr, orElse: () => null);
                  
                  // Rule: Don't deduct leaves for Sundays
                  if (DateFormat('EEEE').format(current) != 'Sunday') {
                    if (holiday != null && (holiday['type'] == 'Public' && holiday['duration'] == 'Full Day')) {
                      // Rule: Don't deduct for public holidays
                      holidayCount++;
                    } else if (holiday != null && holiday['duration'] == 'Half Day') {
                      // Rule: Only deduct 0.5 days if it's a half-day holiday
                      days += 0.5;
                    } else {
                      // Regular working day: deduct 1 full day
                      days += 1.0;
                    }
                  }
                  current = current.add(const Duration(days: 1));
                }

                return Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: PulseColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${days.toStringAsFixed(1)} days deducted ($holidayCount public holidays excluded)',
                        style: PulseTextStyles.captionBold.copyWith(color: PulseColors.accent),
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 16),
          ],

          TextFormField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: 'Reason for leave'),
            maxLines: 2,
            style: PulseTextStyles.body,
            validator: (v) => v!.isEmpty ? 'Please enter a reason' : null,
          ),
          const SizedBox(height: 16),
          PulseButton(
            text: 'Submit Request',
            onPressed: _submitRequest,
          ),
        ],
      ),
    );
  }

  // A reusable button that opens the Calendar popup
  Widget _dateSelector(String label, DateTime? date, Function(DateTime) onSelected, {DateTime? firstDate}) {
    return GestureDetector(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: firstDate ?? DateTime.now(),
          firstDate: firstDate ?? DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (selected != null) onSelected(selected);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: PulseColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PulseColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: PulseTextStyles.caption),
            const SizedBox(height: 4),
            Text(
              date == null ? 'Select' : DateFormat('MMM d, y').format(date),
              style: PulseTextStyles.bodyBold.copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // The scrollable list showing previous requests (Approved, Pending, or Rejected)
  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(
        child: Text('No leave records found.', style: PulseTextStyles.body),
      );
    }
    return ListView.builder(
      shrinkWrap: true, // Needed because this list is inside a SingleChildScrollView
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final leave = _history[index];
        final statusColor = _getStatusColor(leave['status']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PulseCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${leave['startDate']} → ${leave['endDate']}',
                        style: PulseTextStyles.bodyBold.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(leave['reason'], style: PulseTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Status indicator (badge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    leave['status'],
                    style: PulseTextStyles.captionBold.copyWith(color: statusColor, fontSize: 11),
                  ),
                ),
                // Only Pending requests can be cancelled
                if (leave['status'] == 'Pending')
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: PulseColors.textHint, size: 20),
                    onPressed: () => _cancelRequest(leave['id']),
                    tooltip: 'Cancel',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved': return PulseColors.success;
      case 'Rejected': return PulseColors.error;
      default: return PulseColors.warning;
    }
  }
}
