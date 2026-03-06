// --- 10. The Holiday Calendar ---
// This allows the Admin to set "Special Days" for the company.
// Public holidays prevent "Absent" marks for everyone, and Half-Days 
// adjust the expected working hours for that day.

import 'package:flutter/material.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';
import '../../core/widgets/pulse_shimmer.dart';
import '../../core/widgets/pulse_empty_state.dart';
import '../../services/api_service.dart';

class AdminHolidaysScreen extends StatefulWidget {
  const AdminHolidaysScreen({super.key});

  @override
  State<AdminHolidaysScreen> createState() => _AdminHolidaysScreenState();
}

class _AdminHolidaysScreenState extends State<AdminHolidaysScreen> {
  List<dynamic> _holidays = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHolidays();
  }

  Future<void> _loadHolidays() async {
    setState(() => _isLoading = true);
    try {
      final holidays = await ApiService.getHolidays();
      if (mounted) setState(() => _holidays = holidays);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Opens a pop-up to add a new holiday to the system
  Future<void> _addHoliday() async {
    final nameController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedType = 'Public';
    String selectedDuration = 'Full Day';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add Holiday'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Holiday Name')),
            const SizedBox(height: 16),
            // Type: "Public" (Holiday for all) vs "Optional"
            DropdownButtonFormField<String>(
              value: selectedType, decoration: const InputDecoration(labelText: 'Type'),
              items: ['Public', 'Optional', 'Indian'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setD(() => selectedType = v!),
            ),
            const SizedBox(height: 16),
            // Duration: Full vs Half (Half days have special logic in payroll)
            DropdownButtonFormField<String>(
              value: selectedDuration, decoration: const InputDecoration(labelText: 'Duration'),
              items: ['Full Day', 'Half Day'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setD(() => selectedDuration = v!),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
              onPressed: () async {
                final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2030));
                if (d != null) setD(() => selectedDate = d);
              },
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                try {
                  await ApiService.addHoliday(nameController.text, dateStr, type: selectedType, duration: selectedDuration);
                  if (mounted) { Navigator.pop(ctx); _loadHolidays(); }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteHoliday(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Holiday?'),
        content: Text('Remove "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: PulseColors.error))),
        ],
      ),
    );
    if (confirm == true) {
      try { await ApiService.deleteHoliday(id); _loadHolidays(); } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Logic: Split holidays into categories for the tabs
    // Global holidays (company is null) go to Indian tab. 
    // Company-specific holidays go to Company tab UNLESS explicitly set to 'Indian'.
    final indianHolidays = _holidays.where((h) => h['company'] == null || h['type'] == 'Indian').toList();
    final companyHolidays = _holidays.where((h) => h['company'] != null && h['type'] != 'Indian').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Holidays'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Company Holidays'),
              Tab(text: 'Indian Holidays'),
            ],
            indicatorColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? Padding(padding: const EdgeInsets.all(20), child: PulseShimmer.list(count: 5, itemHeight: 70))
            : TabBarView(
                children: [
                  _buildHolidayList(companyHolidays, 'No Company Holidays'),
                  _buildHolidayList(indianHolidays, 'No Indian Holidays'),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addHoliday,
          backgroundColor: PulseColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHolidayList(List<dynamic> list, String emptyTitle) {
    if (list.isEmpty) {
      return Center(child: PulseEmptyState(icon: Icons.beach_access, title: emptyTitle, subtitle: 'Tap + to add one'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final h = list[i];
        final isPublic = h['type'] == 'Public';
        final isIndian = h['type'] == 'Indian';
        final color = isIndian ? PulseColors.accent : (isPublic ? PulseColors.success : PulseColors.warning);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PulseCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.celebration, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                   Flexible(child: Text(h['name'], style: PulseTextStyles.bodyBold, overflow: TextOverflow.ellipsis)),
                   if (h['duration'] == 'Half Day') ...[
                     const SizedBox(width: 6),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                       decoration: BoxDecoration(color: PulseColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                       child: Text('½ Day', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.accent, fontSize: 9)),
                     ),
                   ],
                ]),
                const SizedBox(height: 2),
                Text('${h['date']} • ${h['type']} • ${h['duration']}', style: PulseTextStyles.caption.copyWith(fontSize: 11)),
              ])),
              IconButton(icon: Icon(Icons.delete, color: PulseColors.error, size: 20), onPressed: () => _deleteHoliday(h['id'], h['name'])),
            ]),
          ),
        );
      },
    );
  }
}
