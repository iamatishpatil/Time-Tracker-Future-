import 'package:flutter/material.dart';
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

  Future<void> _addHoliday() async {
    final nameController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add Holiday'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Holiday Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setD(() => selectedDate = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2,'0')}-${selectedDate.day.toString().padLeft(2,'0')}';
                try {
                  await ApiService.addHoliday(nameController.text, dateStr);
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
        content: Text('Remove "$name" from holidays?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.deleteHoliday(id);
        _loadHolidays();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Holidays')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _holidays.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.beach_access, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No holidays added yet', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _holidays.length,
                  itemBuilder: (ctx, i) {
                    final h = _holidays[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(Icons.celebration, color: Colors.green),
                        ),
                        title: Text(h['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(h['date']),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteHoliday(h['id'], h['name']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addHoliday,
        child: const Icon(Icons.add),
      ),
    );
  }
}
