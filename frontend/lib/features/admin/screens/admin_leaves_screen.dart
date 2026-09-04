import 'package:cached_network_image/cached_network_image.dart';
// --- 4. The Leave Approval Screen ---
// This is where Admins review "Time-Off" requests. They can see the reason,
// the dates, and then decide to Approve or Reject the request.

import 'package:flutter/material.dart';
import 'package:frontend/core/theme/pulse_colors.dart';
import 'package:frontend/core/theme/pulse_text_styles.dart';
import 'package:frontend/core/widgets/pulse_card.dart';
import 'package:frontend/core/widgets/pulse_shimmer.dart';
import 'package:frontend/core/widgets/pulse_empty_state.dart';
import 'package:frontend/core/services/api_service.dart';

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
  Future<void> _updateStatus(int id, String status, {String? reason}) async {
    try {
      await ApiService.updateLeaveStatus(id, status, rejectionReason: reason);
      // Refresh the list so the card changes color immediately
      _loadLeaves();
      if (mounted && status == 'Rejected') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⛔ Request Rejected')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<String?> _showRejectionDialog(Map<String, dynamic> leave) async {
    final TextEditingController reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Leave Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter reason for rejecting ${leave['fullName']}\'s request:', style: PulseTextStyles.caption),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'e.g. Incomplete project, Staff shortage',
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
                  itemExtent: 220.0, // Fixed height optimization for 60fps scrolling
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
                backgroundImage: leave['profilePicture'] != null ? CachedNetworkImageProvider(ApiService.getImageUrl(leave['profilePicture'])) : null,
                child: leave['profilePicture'] == null ? const Icon(Icons.person, size: 20, color: PulseColors.textHint) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(leave['fullName'] ?? 'User', style: PulseTextStyles.bodyBold),
                Text(leave['leaveType'] ?? 'Leave', style: PulseTextStyles.caption),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3), width: 1),
                ),
                child: Text(status.toUpperCase(), style: PulseTextStyles.chip.copyWith(color: color)),
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
                  onPressed: () async {
                    final String? reason = await _showRejectionDialog(leave);
                    if (reason != null) {
                      _updateStatus(leave['id'], 'Rejected', reason: reason);
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: PulseColors.error),
                  child: Text('Reject', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.error)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _updateStatus(leave['id'], 'Approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PulseColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    minimumSize: const Size(80, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Approve', style: PulseTextStyles.captionBold.copyWith(color: Colors.white)),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
