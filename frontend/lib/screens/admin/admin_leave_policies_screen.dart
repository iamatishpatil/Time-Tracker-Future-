import 'package:flutter/material.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';
import '../../core/widgets/pulse_shimmer.dart';
import '../../services/api_service.dart';

class AdminLeavePoliciesScreen extends StatefulWidget {
  const AdminLeavePoliciesScreen({super.key});

  @override
  State<AdminLeavePoliciesScreen> createState() => _AdminLeavePoliciesScreenState();
}

class _AdminLeavePoliciesScreenState extends State<AdminLeavePoliciesScreen> {
  List<dynamic> _policies = [];
  List<dynamic> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final policies = await ApiService.getLeavePolicies();
      final employees = await ApiService.getAllUsers();
      if (mounted) setState(() { _policies = policies; _employees = employees; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editPolicy(Map<String, dynamic> policy) async {
    final daysController = TextEditingController(text: policy['daysPerYear'].toString());
    bool isPaid = (policy['isPaid'] == 1 || policy['isPaid'] == true);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Edit: ${policy['leaveType']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: daysController, decoration: const InputDecoration(labelText: 'Days Per Year'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text('Paid Leave', style: PulseTextStyles.bodyBold),
              subtitle: Text(isPaid ? 'Salary is not deducted' : 'Salary is deducted', style: PulseTextStyles.caption),
              value: isPaid,
              onChanged: (v) => setD(() => isPaid = v),
              activeColor: PulseColors.success,
              contentPadding: EdgeInsets.zero,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.saveLeavePolicy({'leaveType': policy['leaveType'], 'daysPerYear': int.tryParse(daysController.text) ?? 10, 'isPaid': isPaid});
                  if (mounted) { Navigator.pop(ctx); _loadData(); }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adjustBalance() async {
    int? selectedUserId;
    String? selectedLeaveType;
    final daysController = TextEditingController(text: '10');
    List<String> dynamicLeaveTypes = _policies.map<String>((p) => p['leaveType'] as String).toList();
    if (dynamicLeaveTypes.isNotEmpty) selectedLeaveType = dynamicLeaveTypes.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Adjust Leave Balance'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              hint: const Text('Select Employee'),
              decoration: const InputDecoration(labelText: 'Employee'),
              items: _employees.map<DropdownMenuItem<int>>((e) => DropdownMenuItem(value: e['id'] as int, child: Text(e['fullName']))).toList(),
              onChanged: (v) => setD(() => selectedUserId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedLeaveType, decoration: const InputDecoration(labelText: 'Leave Type'),
              items: dynamicLeaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setD(() => selectedLeaveType = v!),
            ),
            const SizedBox(height: 12),
            TextField(controller: daysController, decoration: const InputDecoration(labelText: 'Total Days Allowed'), keyboardType: TextInputType.number),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: (selectedUserId == null || selectedLeaveType == null) ? null : () async {
                try {
                  await ApiService.adjustLeaveBalance(selectedUserId!, selectedLeaveType!, int.tryParse(daysController.text) ?? 10);
                  if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Balance adjusted'))); }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Policies'),
        actions: [
          IconButton(icon: const Icon(Icons.tune), tooltip: 'Adjust Balance', onPressed: _adjustBalance),
        ],
      ),
      body: _isLoading
          ? Padding(padding: const EdgeInsets.all(20), child: PulseShimmer.list(count: 4, itemHeight: 70))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _policies.length,
              itemBuilder: (ctx, i) {
                final p = _policies[i];
                final isPaid = p['isPaid'] == 1 || p['isPaid'] == true;
                final color = isPaid ? PulseColors.success : PulseColors.warning;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PulseCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: Icon(isPaid ? Icons.attach_money : Icons.money_off, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p['leaveType'], style: PulseTextStyles.bodyBold),
                        Text('${p['daysPerYear']} days/year  •  ${(p['daysPerYear'] / 12).toStringAsFixed(1)}/mo  •  ${isPaid ? 'Paid' : 'Unpaid'}', style: PulseTextStyles.caption),
                      ])),
                      IconButton(icon: Icon(Icons.edit, color: PulseColors.accent, size: 20), onPressed: () => _editPolicy(p)),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
