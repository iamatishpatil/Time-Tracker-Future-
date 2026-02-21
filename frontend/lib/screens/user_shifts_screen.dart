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
    return Scaffold(
      appBar: AppBar(title: const Text('Company Shifts')),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PulseShimmer.list(count: 3, itemHeight: 90))
          : _shifts.isEmpty
              ? const Center(
                  child: PulseEmptyState(
                      icon: Icons.schedule,
                      title: 'No Shifts Available',
                      subtitle: 'Contact your administrator for assigned shifts.'))
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
                    );
                  },
                ),
    );
  }
}
