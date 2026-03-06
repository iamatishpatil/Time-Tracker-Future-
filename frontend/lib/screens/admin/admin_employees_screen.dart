import 'package:cached_network_image/cached_network_image.dart';
// --- 2. The Employees Directory ---
// This is the "Phonebook" of the company. Admins can see every staff member,
// search for them, and turn their access ON or OFF.

import 'package:flutter/material.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';
import 'package:frontend/core/widgets/pulse_shimmer.dart';
import 'package:frontend/core/widgets/pulse_empty_state.dart';
import '../../services/api_service.dart';
import 'employee_form_screen.dart';

class AdminEmployeesScreen extends StatefulWidget {
  final bool isTab;
  const AdminEmployeesScreen({super.key, this.isTab = false});

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

  // Fetch the full list of humans from the database
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: widget.isTab ? null : AppBar(
          title: const Text('Employees'),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Directory'),
              Tab(text: 'Approvals'),
            ],
            labelStyle: PulseTextStyles.captionBold,
            unselectedLabelStyle: PulseTextStyles.caption,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(width: 3.5, color: PulseColors.primary),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              insets: const EdgeInsets.symmetric(horizontal: 48),
            ),
            splashBorderRadius: BorderRadius.circular(12),
          ),
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
        body: Column(
          children: [
            if (widget.isTab)
              TabBar(
                tabs: const [
                  Tab(text: 'Directory'),
                  Tab(text: 'Approvals'),
                ],
                labelColor: PulseColors.primary,
                unselectedLabelColor: PulseColors.textHint,
                labelStyle: PulseTextStyles.captionBold,
                unselectedLabelStyle: PulseTextStyles.caption,
                indicatorColor: PulseColors.primary,
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildEmployeeList(approvedOnly: true),
                  _buildEmployeeList(approvedOnly: false),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: widget.isTab ? FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeFormScreen()));
            if (result == true) _loadEmployees();
          },
          backgroundColor: PulseColors.primary,
          child: const Icon(Icons.person_add, color: Colors.white),
        ) : null,
      ),
    );
  }

  Widget _buildEmployeeList({required bool approvedOnly}) {
    final filtered = _employees.where((e) {
      final bool approved = e['isApproved'] != 0 && e['isApproved'] != false;
      return approvedOnly ? approved : !approved;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadEmployees,
      child: _isLoading
          ? Padding(padding: const EdgeInsets.all(20), child: PulseShimmer.list(count: 5, itemHeight: 110))
          : filtered.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    PulseEmptyState(
                      icon: approvedOnly ? Icons.people_outline : Icons.how_to_reg_outlined, 
                      title: approvedOnly ? 'No Employees' : 'No Pending Approvals', 
                      subtitle: approvedOnly ? 'Staff members will appear here.' : 'New registrations will show up here for you to review.',
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  itemCount: filtered.length,
                  itemExtent: 185.0, // Fixed height optimization for 60fps scrolling
                  itemBuilder: (context, index) => _buildCard(filtered[index]),
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
                      ? CachedNetworkImageProvider(ApiService.getImageUrl(employee['profilePicture']))
                      : null,
                  child: employee['profilePicture'] == null ? const Icon(Icons.person, size: 24, color: PulseColors.textHint) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(employee['fullName'] ?? 'User', style: PulseTextStyles.bodyBold, overflow: TextOverflow.ellipsis)),
                          if (employee['isApproved'] == 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: PulseColors.warning.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: PulseColors.warning.withValues(alpha: 0.3), width: 1),
                              ),
                              child: Text('PENDING', style: PulseTextStyles.chip.copyWith(color: PulseColors.warning)),
                            ),
                        ],
                      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // --- Conditional Actions based on Approval Status ---
                if (employee['isApproved'] == 0)
                  // Approval Buttons for Pending Users
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final String? reason = await _showRejectionDialog(employee);
                          if (reason != null) {
                            try {
                              await ApiService.toggleUserApproval(employee['id'], false, reason: reason);
                              _loadEmployees();
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⛔ User Rejected')));
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                            }
                          }
                        },
                        style: TextButton.styleFrom(foregroundColor: PulseColors.error),
                        child: Text('Reject', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.error)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await ApiService.toggleUserApproval(employee['id'], true);
                            _loadEmployees();
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ User Approved')));
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PulseColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(80, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Approve', style: PulseTextStyles.captionBold.copyWith(color: Colors.white)),
                      ),
                    ],
                  )
                else
                  // Status Switch for Approved Users
                  Row(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? PulseColors.success.withValues(alpha: 0.08) : PulseColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (isActive ? PulseColors.success : PulseColors.error).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isActive ? 'ACTIVE' : 'INACTIVE',
                          style: PulseTextStyles.chip.copyWith(
                            color: isActive ? PulseColors.success : PulseColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
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
                          activeThumbColor: PulseColors.success,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: PulseColors.accent, size: 20),
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

  Future<String?> _showRejectionDialog(Map<String, dynamic> employee) async {
    final TextEditingController reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter reason for rejecting ${employee['fullName']}:', style: PulseTextStyles.caption),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'e.g. Invalid document, Outside hiring zone',
                hintStyle: PulseTextStyles.caption.copyWith(color: PulseColors.textHint),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: PulseColors.error)),
              ),
              maxLines: 3,
              style: PulseTextStyles.body,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a reason')));
                return;
              }
              Navigator.pop(context, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: PulseColors.error, foregroundColor: Colors.white),
            child: const Text('REJECT'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> employee, {bool isReject = false}) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isReject ? 'Reject User' : 'Delete Employee'),
        content: Text(isReject 
            ? 'Reject and remove registration for ${employee['fullName']}?' 
            : 'Delete ${employee['fullName']}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: PulseColors.error),
            child: Text(isReject ? 'REJECT' : 'DELETE'),
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
