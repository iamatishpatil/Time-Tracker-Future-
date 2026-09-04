import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/pulse_colors.dart';
import 'package:frontend/core/theme/pulse_text_styles.dart';
import 'package:frontend/core/widgets/pulse_card.dart';
import 'package:frontend/core/widgets/pulse_shimmer.dart';
import 'package:frontend/core/widgets/pulse_empty_state.dart';
import 'package:frontend/core/services/api_service.dart';

class AdminAbsentScreen extends StatefulWidget {
  const AdminAbsentScreen({super.key});

  @override
  State<AdminAbsentScreen> createState() => _AdminAbsentScreenState();
}

class _AdminAbsentScreenState extends State<AdminAbsentScreen> {
  List<dynamic> _absentEmployees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAbsent();
  }

  Future<void> _loadAbsent() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAbsentEmployees();
      if (mounted) setState(() => _absentEmployees = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Absent Today')),
      body: _isLoading
          ? Padding(padding: const EdgeInsets.all(20), child: PulseShimmer.list(count: 4, itemHeight: 70))
          : _absentEmployees.isEmpty
              ? const Center(child: PulseEmptyState(icon: Icons.check_circle_outline, title: 'All Present!', subtitle: 'No absences reported today'))
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _absentEmployees.length,
                  itemBuilder: (context, index) {
                    final employee = _absentEmployees[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PulseCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 22, backgroundColor: PulseColors.surfaceVariant,
                            backgroundImage: employee['profilePicture'] != null ? CachedNetworkImageProvider(ApiService.getImageUrl(employee['profilePicture'])) : null,
                            child: employee['profilePicture'] == null ? const Icon(Icons.person, size: 22, color: PulseColors.textHint) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(employee['fullName'] ?? 'Unknown', style: PulseTextStyles.bodyBold),
                            Text(employee['mobileNumber'] ?? '', style: PulseTextStyles.caption.copyWith(fontSize: 11)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: PulseColors.error.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text('Absent', style: PulseTextStyles.captionBold.copyWith(color: PulseColors.error, fontSize: 11)),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
