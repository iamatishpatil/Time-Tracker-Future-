import 'package:flutter/material.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';
import '../../core/widgets/pulse_shimmer.dart';
import '../../core/widgets/pulse_empty_state.dart';
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

    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    if (existing != null) {
      final sp = (existing['startTime'] as String).split(':');
      final ep = (existing['endTime'] as String).split(':');
      startTime = TimeOfDay(hour: int.parse(sp[0]), minute: int.parse(sp[1]));
      endTime = TimeOfDay(hour: int.parse(ep[0]), minute: int.parse(ep[1]));
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Shift' : 'Add New Shift'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Shift Name')),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextButton.icon(
                icon: const Icon(Icons.access_time),
                label: Text('Start: ${startTime.format(context)}'),
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: startTime);
                  if (t != null) setDialogState(() => startTime = t);
                },
              )),
              Expanded(child: TextButton.icon(
                icon: const Icon(Icons.access_time_filled),
                label: Text('End: ${endTime.format(context)}'),
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: endTime);
                  if (t != null) setDialogState(() => endTime = t);
                },
              )),
            ]),
            const SizedBox(height: 16),
            TextField(controller: graceController, decoration: const InputDecoration(labelText: 'Grace Period (mins)'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            TextField(controller: overtimeController, decoration: const InputDecoration(labelText: 'Overtime Rate (e.g., 1.5x)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 16),
            TextField(controller: penaltyController, decoration: const InputDecoration(labelText: 'Late Penalty per Min (₹)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter shift name')));
                  return;
                }
                final data = {
                  'name': nameController.text,
                  'startTime': '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}',
                  'endTime': '${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}',
                  'gracePeriodMins': int.tryParse(graceController.text) ?? 0,
                  'overtimeRate': double.tryParse(overtimeController.text) ?? 1.0,
                  'latePenaltyPerMin': double.tryParse(penaltyController.text) ?? 0,
                };
                try {
                  if (isEdit) { await ApiService.updateShift(existing['id'], data); } else { await ApiService.createShift(data); }
                  if (mounted) { Navigator.pop(ctx); _loadShifts(); }
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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: PulseColors.error))),
        ],
      ),
    );
    if (confirm == true) {
      try { await ApiService.deleteShift(id); _loadShifts(); } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Shifts')),
      body: _isLoading
          ? Padding(padding: const EdgeInsets.all(20), child: PulseShimmer.list(count: 3, itemHeight: 90))
          : _shifts.isEmpty
              ? const Center(child: PulseEmptyState(icon: Icons.schedule, title: 'No Shifts', subtitle: 'Tap + to add one'))
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _shifts.length,
                  itemBuilder: (context, index) {
                    final shift = _shifts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PulseCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: PulseColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.schedule, color: PulseColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(shift['name'], style: PulseTextStyles.bodyBold),
                              const SizedBox(height: 2),
                              Text('${shift['startTime']} – ${shift['endTime']}', style: PulseTextStyles.caption),
                              const SizedBox(height: 2),
                              Text('Grace: ${shift['gracePeriodMins']}m  •  OT: ${shift['overtimeRate']}x  •  ₹${shift['latePenaltyPerMin'] ?? 0}/min',
                                  style: PulseTextStyles.caption.copyWith(fontSize: 10)),
                            ])),
                            IconButton(icon: Icon(Icons.edit, color: PulseColors.accent, size: 20), onPressed: () => _showShiftDialog(existing: shift)),
                            IconButton(icon: Icon(Icons.delete, color: PulseColors.error, size: 20), onPressed: () => _deleteShift(shift['id'])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showShiftDialog(),
        backgroundColor: PulseColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
