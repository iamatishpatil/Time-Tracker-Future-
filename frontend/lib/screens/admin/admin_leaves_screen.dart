// --- 4. The Leave Approval Screen ---
// This is where Admins review "Time-Off" requests. They can see the reason,
// the dates, and then decide to Approve or Reject the request.

import 'package:flutter/material.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';
import '../../core/widgets/pulse_shimmer.dart';
import '../../core/widgets/pulse_empty_state.dart';
import '../../services/api_service.dart';

class AdminLeavesScreen extends StatefulWidget {
  final bool isTab;
  const AdminLeavesScreen({super.key, this.isTab = false});

  @override
  State<AdminLeavesScreen> createState() => _AdminLeavesScreenState();
}

class _AdminLeavesScreenState extends State<AdminLeavesScreen> {
  List<dynamic> _leaves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAllLeaves();
      if (mounted) setState(() => _leaves = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // The function to change a "Pending" request into "Approved" or "Rejected"
  Future<void> _updateStatus(int id, String status) async {
    try {
      await ApiService.updateLeaveStatus(id, status);
      // Refresh the list so the card changes color immediately
      _loadLeaves();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: _loadLeaves,
      child: _isLoading
          ? Padding(padding: const EdgeInsets.all(20), child: PulseShimmer.list(count: 4, itemHeight: 130))
          : _leaves.isEmpty
              ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                  SizedBox(height: 80),
                  PulseEmptyState(icon: Icons.beach_access_outlined, title: 'No Requests', subtitle: 'Pull to refresh'),
                ])
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  itemCount: _leaves.length,
                  itemBuilder: (context, index) => _buildCard(_leaves[index]),
                ),
    );

    if (widget.isTab) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('Leave Management')),
      body: content,
    );
  }

  Widget _buildCard(Map<String, dynamic> leave) {
    final status = leave['status'] ?? 'Pending';
    final color = status == 'Approved' ? PulseColors.success : (status == 'Rejected' ? PulseColors.error : PulseColors.warning);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PulseCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(children: [
              CircleAvatar(
                radius: 20, backgroundColor: PulseColors.surfaceVariant,
                backgroundImage: leave['profilePicture'] != null ? NetworkImage(ApiService.getImageUrl(leave['profilePicture'])) : null,
                child: leave['profilePicture'] == null ? const Icon(Icons.person, size: 20, color: PulseColors.textHint) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(leave['fullName'] ?? 'User', style: PulseTextStyles.bodyBold),
                Text(leave['leaveType'] ?? 'Leave', style: PulseTextStyles.caption),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(status, style: PulseTextStyles.captionBold.copyWith(color: color, fontSize: 10)),
              ),
            ]),
            const SizedBox(height: 10),
            Divider(height: 1, color: PulseColors.border),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.calendar_today, size: 13, color: PulseColors.textHint),
              const SizedBox(width: 6),
              Text('${leave['startDate']} → ${leave['endDate']}', style: PulseTextStyles.caption.copyWith(fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.notes, size: 13, color: PulseColors.textHint),
              const SizedBox(width: 6),
              Expanded(child: Text(leave['reason'] ?? 'No reason', style: PulseTextStyles.caption.copyWith(fontSize: 11))),
            ]),
            // If the request hasn't been dealt with yet, show the "YES/NO" buttons
            if (status == 'Pending') ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => _updateStatus(leave['id'], 'Rejected'),
                  child: Text('REJECT', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.error)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _updateStatus(leave['id'], 'Approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PulseColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    minimumSize: const Size(80, 34),
                  ),
                  child: const Text('APPROVE'),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
