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
    // Logic: Split holidays into categories for the tabs
    // Global holidays (company is null) or those typed 'Indian' go to National tab.
    // Company-specific holidays that are not 'Indian' go to Company tab.
    final nationalHolidays = _holidays.where((h) => h['company'] == null || h['type'] == 'Indian').toList();
    final companyHolidays = _holidays.where((h) => h['company'] != null && h['type'] != 'Indian').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Holidays ${DateTime.now().year}'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Company Holidays'),
              Tab(text: 'National Holidays'),
            ],
            indicatorColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: PulseShimmer.list(count: 6, itemHeight: 80),
              )
            : TabBarView(
                children: [
                  _buildHolidayList(companyHolidays, 'No Company Holidays'),
                  _buildHolidayList(nationalHolidays, 'No National Holidays'),
                ],
              ),
      ),
    );
  }

  Widget _buildHolidayList(List<dynamic> list, String emptyTitle) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.beach_access_outlined, size: 64, color: PulseColors.textHint.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(emptyTitle, style: PulseTextStyles.bodyBold.copyWith(color: PulseColors.textHint)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final holiday = list[index];
        final date = DateTime.parse(holiday['date']);
        final isPublic = holiday['type'] == 'Public';
        final isIndian = holiday['type'] == 'Indian';
        final isHalfDay = holiday['duration'] == 'Half Day';
        final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
        final color = isIndian ? PulseColors.accent : (isPublic ? PulseColors.success : PulseColors.warning);

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
                          holiday['type'],
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
    );
  }
}
