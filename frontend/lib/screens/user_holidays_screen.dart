import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../core/widgets/pulse_card.dart';
import '../core/widgets/pulse_shimmer.dart';
import '../services/api_service.dart';

class UserHolidaysScreen extends StatefulWidget {
  const UserHolidaysScreen({super.key});

  @override
  State<UserHolidaysScreen> createState() => _UserHolidaysScreenState();
}

class _UserHolidaysScreenState extends State<UserHolidaysScreen> {
  List<dynamic> _holidays = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHolidays();
  }

  Future<void> _loadHolidays() async {
    try {
      final data = await ApiService.getHolidays();
      if (mounted) {
        setState(() {
          _holidays = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Holidays ${DateTime.now().year}'),
      ),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PulseShimmer.list(count: 6, itemHeight: 80),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _holidays.length,
              itemBuilder: (context, index) {
                final holiday = _holidays[index];
                final date = DateTime.parse(holiday['date']);
                final isPublic = holiday['type'] == 'Public';
                final isHalfDay = holiday['duration'] == 'Half Day';
                final isPast = date.isBefore(DateTime.now());
                final color = isPublic ? PulseColors.success : PulseColors.warning;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PulseCard(
                    padding: const EdgeInsets.all(14),
                    child: Opacity(
                      opacity: isPast ? 0.5 : 1.0,
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('d').format(date),
                                  style: PulseTextStyles.h3.copyWith(color: color, fontSize: 20),
                                ),
                                Text(
                                  DateFormat('MMM').format(date).toUpperCase(),
                                  style: PulseTextStyles.captionBold.copyWith(color: color, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(holiday['name'], style: PulseTextStyles.bodyBold),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('EEEE').format(date),
                                  style: PulseTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isHalfDay)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: PulseColors.accent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '½ Day',
                                    style: PulseTextStyles.captionBold.copyWith(
                                      color: PulseColors.accent,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isPublic ? 'Public' : 'Optional',
                                  style: PulseTextStyles.captionBold.copyWith(color: color, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
