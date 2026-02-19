import 'package:flutter/material.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';
import '../../core/widgets/pulse_shimmer.dart';
import '../../core/widgets/pulse_empty_state.dart';
import '../../services/api_service.dart';
import 'employee_form_screen.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  List<dynamic> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAllUsers();
      if (mounted) setState(() => _employees = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeFormScreen()));
              if (result == true) _loadEmployees();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEmployees,
        child: _isLoading
            ? Padding(padding: const EdgeInsets.all(20), child: PulseShimmer.list(count: 5, itemHeight: 110))
            : _employees.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      PulseEmptyState(icon: Icons.people_outline, title: 'No Employees', subtitle: 'Tap + to add one'),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(14),
                    itemCount: _employees.length,
                    itemBuilder: (context, index) => _buildCard(_employees[index]),
                  ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> employee) {
    final bool isActive = employee['isActive'] != 0 && employee['isActive'] != false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PulseCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: PulseColors.surfaceVariant,
                  backgroundImage: employee['profilePicture'] != null
                      ? NetworkImage(ApiService.getImageUrl(employee['profilePicture']))
                      : null,
                  child: employee['profilePicture'] == null ? const Icon(Icons.person, size: 24, color: PulseColors.textHint) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee['fullName'] ?? 'User', style: PulseTextStyles.bodyBold, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${employee['role'] ?? 'Employee'} • ${employee['shiftName'] ?? 'No Shift'}',
                          style: PulseTextStyles.caption, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.phone_outlined, size: 12, color: PulseColors.textHint),
                        const SizedBox(width: 4),
                        Flexible(child: Text(employee['mobileNumber'] ?? 'N/A', style: PulseTextStyles.caption.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.calendar_today_outlined, size: 12, color: PulseColors.accent),
                        const SizedBox(width: 4),
                        Flexible(child: Text('Off: ${employee['weekOffs'] ?? 'Sunday'}',
                            style: PulseTextStyles.caption.copyWith(color: PulseColors.accent, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: PulseColors.border),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(isActive ? 'Active' : 'Inactive',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? PulseColors.success : PulseColors.error)),
                  Switch(
                    value: isActive,
                    onChanged: (val) async {
                      setState(() => employee['isActive'] = val ? 1 : 0);
                      try {
                        await ApiService.toggleEmployeeActive(employee['id'], val);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? '✅ Activated' : '⛔ Deactivated'), duration: const Duration(seconds: 2)));
                      } catch (e) {
                        setState(() => employee['isActive'] = val ? 0 : 1);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                    activeColor: PulseColors.success,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: PulseColors.accent, size: 20),
                    onPressed: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeFormScreen(employee: employee)));
                      if (result == true) _loadEmployees();
                    },
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: PulseColors.error, size: 20),
                    onPressed: () => _confirmDelete(employee),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> employee) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Delete ${employee['fullName']}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: PulseColors.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteUser(employee['id']);
        _loadEmployees();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
