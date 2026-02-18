import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminShiftsScreen extends StatefulWidget {
  const AdminShiftsScreen({super.key});

  @override
  State<AdminShiftsScreen> createState() => _AdminShiftsScreenState();
}

class _AdminShiftsScreenState extends State<AdminShiftsScreen> {
  List<dynamic> _shifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _isLoading = true);
    try {
      final shifts = await ApiService.getShifts();
      if (mounted) setState(() => _shifts = shifts);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showShiftDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final graceController = TextEditingController(text: (existing?['gracePeriodMins'] ?? 0).toString());
    final overtimeController = TextEditingController(text: (existing?['overtimeRate'] ?? 1.0).toString());
    final penaltyController = TextEditingController(text: (existing?['latePenaltyPerMin'] ?? 0).toString());

    // Parse existing times or defaults
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    if (existing != null) {
      final startParts = (existing['startTime'] as String).split(':');
      final endParts = (existing['endTime'] as String).split(':');
      startTime = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
      endTime = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Shift' : 'Add New Shift'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Shift Name (e.g., Morning)'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text('Start: ${startTime.format(context)}'),
                        onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: startTime);
                          if (t != null) setDialogState(() => startTime = t);
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.access_time_filled),
                        label: Text('End: ${endTime.format(context)}'),
                        onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: endTime);
                          if (t != null) setDialogState(() => endTime = t);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: graceController,
                  decoration: const InputDecoration(labelText: 'Grace Period (mins)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: overtimeController,
                  decoration: const InputDecoration(labelText: 'Overtime Rate (e.g., 1.5x)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: penaltyController,
                  decoration: const InputDecoration(labelText: 'Late Penalty per Min (₹)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                final data = {
                  'name': nameController.text,
                  'startTime': '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}',
                  'endTime': '${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}',
                  'gracePeriodMins': int.tryParse(graceController.text) ?? 0,
                  'overtimeRate': double.tryParse(overtimeController.text) ?? 1.0,
                  'latePenaltyPerMin': double.tryParse(penaltyController.text) ?? 0,
                };
                try {
                  if (isEdit) {
                    await ApiService.updateShift(existing!['id'], data);
                  } else {
                    await ApiService.createShift(data);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadShifts();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(isEdit ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteShift(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Shift?'),
        content: const Text('This will unassign all employees from this shift.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.deleteShift(id);
        _loadShifts();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Shifts')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shifts.isEmpty
              ? const Center(child: Text('No shifts yet. Tap + to add one.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _shifts.length,
                  itemBuilder: (context, index) {
                    final shift = _shifts[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.schedule)),
                        title: Text(shift['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${shift['startTime']} – ${shift['endTime']}'),
                            Text('Grace: ${shift['gracePeriodMins']}m  |  OT: ${shift['overtimeRate']}x  |  Penalty: ₹${shift['latePenaltyPerMin'] ?? 0}/min',
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showShiftDialog(existing: shift),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteShift(shift['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showShiftDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
