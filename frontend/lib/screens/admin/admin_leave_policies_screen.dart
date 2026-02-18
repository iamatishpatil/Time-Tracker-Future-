import 'package:flutter/material.dart';
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: daysController,
                decoration: const InputDecoration(labelText: 'Days Per Year'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Paid Leave'),
                value: isPaid,
                onChanged: (v) => setD(() => isPaid = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.saveLeavePolicy({
                    'leaveType': policy['leaveType'],
                    'daysPerYear': int.tryParse(daysController.text) ?? 10,
                    'isPaid': isPaid,
                  });
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
    String selectedLeaveType = 'Casual Leave';
    final daysController = TextEditingController(text: '10');
    final leaveTypes = ['Sick Leave', 'Casual Leave', 'Annual Leave', 'Unpaid Leave'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Adjust Leave Balance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                hint: const Text('Select Employee'),
                items: _employees.map<DropdownMenuItem<int>>((e) =>
                    DropdownMenuItem(value: e['id'] as int, child: Text(e['fullName']))).toList(),
                onChanged: (v) => setD(() => selectedUserId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedLeaveType,
                items: leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setD(() => selectedLeaveType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: daysController,
                decoration: const InputDecoration(labelText: 'Total Days Allowed'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedUserId == null ? null : () async {
                try {
                  await ApiService.adjustLeaveBalance(
                    selectedUserId!,
                    selectedLeaveType,
                    int.tryParse(daysController.text) ?? 10,
                  );
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
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Adjust Employee Balance',
            onPressed: _adjustBalance,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _policies.length,
              itemBuilder: (ctx, i) {
                final p = _policies[i];
                final isPaid = p['isPaid'] == 1 || p['isPaid'] == true;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPaid ? Colors.green.shade100 : Colors.orange.shade100,
                      child: Icon(isPaid ? Icons.attach_money : Icons.money_off,
                          color: isPaid ? Colors.green : Colors.orange),
                    ),
                    title: Text(p['leaveType'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${p['daysPerYear']} days/year  •  ${isPaid ? 'Paid' : 'Unpaid'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editPolicy(p),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
