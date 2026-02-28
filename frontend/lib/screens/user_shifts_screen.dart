import 'package:flutter/material.dart';
import '../../core/theme/pulse_colors.dart';
import '../../core/theme/pulse_text_styles.dart';
import '../../core/widgets/pulse_card.dart';
import '../../core/widgets/pulse_shimmer.dart';
import '../../core/widgets/pulse_empty_state.dart';
import '../../services/api_service.dart';

class UserShiftsScreen extends StatefulWidget {
  const UserShiftsScreen({super.key});

  @override
  State<UserShiftsScreen> createState() => _UserShiftsScreenState();
}

class _UserShiftsScreenState extends State<UserShiftsScreen> {
  List<dynamic> _shifts = [];
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Performance Fix: Fetch both IN PARALLEL
      final results = await Future.wait([
        ApiService.getShifts(),
        ApiService.getStoredUser(),
      ]);
      final shifts = results[0] as List<dynamic>;
      final user = results[1] as Map<String, dynamic>?;
      if (mounted) setState(() { _shifts = shifts; _user = user; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekOffs = (_user?['weekOffs'] ?? 'Sunday').toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Company Shifts')),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PulseShimmer.list(count: 3, itemHeight: 90))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // Your Week Offs Card
                  PulseCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.weekend, color: PulseColors.warning, size: 20),
                            const SizedBox(width: 8),
                            Text('Your Week Offs', style: PulseTextStyles.bodyBold),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: weekOffs.map((day) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: PulseColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: PulseColors.warning.withOpacity(0.3)),
                            ),
                            child: Text(day, style: PulseTextStyles.captionBold.copyWith(color: PulseColors.warning)),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Shifts Header
                  Text('All Shifts', style: PulseTextStyles.h3),
                  const SizedBox(height: 10),

                  if (_shifts.isEmpty)
                    const PulseEmptyState(
                        icon: Icons.schedule,
                        title: 'No Shifts Available',
                        subtitle: 'Contact your administrator for assigned shifts.')
                  else
                    ..._shifts.map((shift) => Padding(
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
                              child: Icon(Icons.schedule,
                                  color: PulseColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(shift['name'],
                                      style: PulseTextStyles.bodyBold),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${shift['startTime']} – ${shift['endTime']}',
                                      style: PulseTextStyles.caption),
                                  const SizedBox(height: 2),
                                  Text(
                                      'Grace: ${shift['gracePeriodMins']}m  •  OT: ${shift['overtimeRate']}x',
                                      style: PulseTextStyles.caption
                                          .copyWith(fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                ],
              ),
            ),
    );
  }
}

