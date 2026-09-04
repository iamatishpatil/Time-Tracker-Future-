// --- 1. The Attendance History Screen ---
// This screen shows a chronological list of all your previous check-ins.
// It's a great example of how to build a dynamic list in Flutter.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/theme/pulse_colors.dart';
import 'package:frontend/core/theme/pulse_text_styles.dart';
import 'package:frontend/core/widgets/pulse_card.dart';
import 'package:frontend/core/widgets/pulse_shimmer.dart';
import 'package:frontend/core/widgets/pulse_empty_state.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/services/pdf_service.dart';
import 'package:frontend/core/widgets/pulse_scaffold.dart';
import 'package:frontend/core/widgets/pulse_button.dart'; // For smaller icon usage if needed

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;
  String _userName = 'User';
  List<dynamic> _holidays = [];
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // Fetch the data from the server
  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final user = await ApiService.getStoredUser();
      if (user != null) {
        _userName = user['fullName'] ?? 'User';
        // Performance Fix: Fetch both IN PARALLEL
        final results = await Future.wait([
          ApiService.getAttendance(
            user['id'],
            startDate: _selectedRange?.start,
            endDate: _selectedRange?.end,
          ),
          ApiService.getHolidays(),
        ]);
        final history = results[0] as List<dynamic>;
        final holidays = results[1] as List<dynamic>;
        if (mounted) {
          setState(() {
            _history = history;
            _holidays = holidays;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: PulseColors.primary,
              onPrimary: Colors.white,
              onSurface: PulseColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedRange) {
      setState(() {
        _selectedRange = picked;
      });
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PulseScaffold(

      useBrandedBackground: true,
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PulseShimmer.list(count: 4, itemHeight: 120),
            )
          : Column(
              children: [
                // Header Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: PulseCard(
                    glowEffect: true,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: PulseColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.history_rounded, color: PulseColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_userName, style: PulseTextStyles.bodyBold),
                              if (_selectedRange != null)
                                Text(
                                  '${DateFormat('MMM d').format(_selectedRange!.start)} - ${DateFormat('MMM d').format(_selectedRange!.end)}',
                                  style: PulseTextStyles.caption.copyWith(color: PulseColors.primary),
                                )
                              else
                                Text(
                                  '${_history.length} ${_history.length == 1 ? 'Record' : 'Records'}',
                                  style: PulseTextStyles.caption,
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.filter_list_rounded, color: PulseColors.primary, size: 22),
                          onPressed: _selectDateRange,
                          tooltip: 'Filter by Date',
                        ),
                        IconButton(
                          icon: Icon(Icons.picture_as_pdf_rounded, color: PulseColors.primaryLight, size: 22),
                          onPressed: () => PdfService.generateAttendanceReport(_userName, _history, holidays: _holidays),
                          tooltip: 'Export PDF',
                        ),
                      ],
                    ),
                  ),
                ),

                // History List
                Expanded(
                  child: _history.isEmpty
                      ? ListView(
                          // the AlwaysScrollable physics is what lets you "Pull to Refresh" even if the list is empty!
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 60),
                            PulseEmptyState(
                              icon: Icons.history_toggle_off_rounded,
                              title: 'No Records',
                              subtitle: 'Pull down to refresh',
                            ),
                          ],
                        )
                      : ListView.builder(
                          // ListView.builder is EFFICIENT. It only draws what's on the screen.
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final record = _history[index];
                            // Turn the server strings into real Dart Date objects
                            final checkIn = DateTime.parse(record['checkInTime']).toLocal();
                            final checkOut = record['checkOutTime'] != null
                                ? DateTime.parse(record['checkOutTime']).toLocal()
                                : null;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: PulseCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Date row with badges
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            DateFormat('EEEE, MMM d').format(checkIn),
                                            style: PulseTextStyles.bodyBold.copyWith(color: PulseColors.primaryLight),
                                          ),
                                        ),
                                        // Holiday Badge
                                        Builder(builder: (ctx) {
                                          final dateStr = DateFormat('yyyy-MM-dd').format(checkIn);
                                          final holiday = _holidays.firstWhere(
                                              (h) => h['date'] == dateStr, orElse: () => null);
                                          if (holiday != null) {
                                            return Container(
                                              margin: const EdgeInsets.only(right: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: PulseColors.accent.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                holiday['name'].toString().toUpperCase() +
                                                    (holiday['duration'] == 'Half Day' ? ' (½)' : ''),
                                                style: PulseTextStyles.captionBold.copyWith(
                                                  color: PulseColors.accent,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        }),
                                        // Status Badge
                                        _statusBadge(
                                          checkOut == null ? 'Active' : 'Done',
                                          checkOut == null ? PulseColors.warning : PulseColors.success,
                                        ),
                                        if (record['status'] == 'Late')
                                          Padding(
                                            padding: const EdgeInsets.only(left: 6),
                                            child: _statusBadge('LATE', PulseColors.error),
                                          ),
                                        if (record['overtimeHours'] != null &&
                                            (record['overtimeHours'] is num) &&
                                            record['overtimeHours'] > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 6),
                                            child: _statusBadge(
                                              '+${(record['overtimeHours'] as num).toStringAsFixed(1)}h',
                                              PulseColors.accent,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const Divider(color: PulseColors.divider, height: 20),
                                    // Times row
                                    Row(
                                      children: [
                                        // Show when they arrived
                                        Expanded(
                                          child: _timeColumn('Check In', DateFormat('hh:mm a').format(checkIn),
                                              record['checkInPhoto']),
                                        ),
                                        // Show when they left (if they have)
                                        if (checkOut != null)
                                          Expanded(
                                            child: _timeColumn('Check Out', DateFormat('hh:mm a').format(checkOut),
                                                record['checkOutPhoto']),
                                          ),
                                      ],
                                    ),
                                    if (record['checkInAddress'] != null || record['checkOutAddress'] != null) ...[
                                      const SizedBox(height: 12),
                                      if (record['checkInAddress'] != null)
                                        _addressRow('In:', record['checkInAddress']),
                                      if (record['checkOutAddress'] != null) ...[
                                        const SizedBox(height: 4),
                                        _addressRow('Out:', record['checkOutAddress']),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      ),
    );
  }

  // Helper row for showing addresses
  Widget _addressRow(String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 25,
          child: Text(label, style: PulseTextStyles.captionBold.copyWith(fontSize: 10, color: PulseColors.primaryLight)),
        ),
        const Icon(Icons.location_on, size: 12, color: PulseColors.textHint),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            address,
            style: PulseTextStyles.caption.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }

  // A helper to build those small colored boxes like [LATE] or [ACTIVE]
  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: PulseTextStyles.captionBold.copyWith(color: color, fontSize: 10),
      ),
    );
  }

  // A helper to build the time and the selfie image
  Widget _timeColumn(String label, String time, String? photoUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PulseTextStyles.caption),
        const SizedBox(height: 4),
        Text(time, style: PulseTextStyles.bodyBold.copyWith(fontSize: 16)),
        if (photoUrl != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              // ApiService.getImageUrl converts the server path into a clickable URL
              ApiService.getImageUrl(photoUrl),
              height: 70,
              width: 70,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) =>
                  const Icon(Icons.broken_image, size: 30, color: PulseColors.textHint),
            ),
          ),
        ],
      ],
    );
  }
}
