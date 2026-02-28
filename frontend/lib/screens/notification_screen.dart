import 'package:flutter/material.dart';
import '../core/theme/pulse_colors.dart';
import '../core/theme/pulse_text_styles.dart';
import '../core/widgets/pulse_card.dart';
import '../core/widgets/pulse_shimmer.dart';
import '../core/widgets/pulse_empty_state.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final user = await ApiService.getStoredUser();
      if (user != null) {
        // Performance Fix: Fetch both IN PARALLEL
        final results = await Future.wait([
          ApiService.getNotifications(user['id']),
          ApiService.getHolidays(),
        ]);
        var notifications = results[0] as List<dynamic>;
        final holidays = results[1] as List<dynamic>;

        final now = DateTime.now();
        for (var h in holidays) {
          final hDate = DateTime.parse(h['date']);
          final diff = hDate.difference(now).inDays;
          if (diff >= 0 && diff <= 3) {
            notifications.insert(0, {
              'id': -hDate.millisecondsSinceEpoch,
              'title': 'Upcoming Holiday: ${h['name']}',
              'message': 'Reminder: ${h['name']} is on ${DateFormat('EEEE, MMM d').format(hDate)}. It is a ${h['duration']} holiday.',
              'isRead': 0,
              'createdAt': DateTime.now().toIso8601String(),
              'type': 'system_holiday',
            });
          }
        }

        if (mounted) setState(() => _notifications = notifications);
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await ApiService.markNotificationRead(id);
      _loadNotifications();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _isLoading
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: PulseShimmer.list(count: 5, itemHeight: 80),
              )
            : _notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      PulseEmptyState(
                        icon: Icons.notifications_off_outlined,
                        title: 'No Notifications',
                        subtitle: 'You\'re all caught up!',
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final isRead = notif['isRead'] == 1;
                      return Dismissible(
                        key: Key(notif['id'].toString()),
                        background: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: PulseColors.primary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.mark_email_read, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) => _markAsRead(notif['id']),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: PulseCard(
                            color: isRead ? null : PulseColors.primary.withOpacity(0.08),
                            borderColor: isRead ? null : PulseColors.primary.withOpacity(0.2),
                            onTap: () {
                              if (!isRead) _markAsRead(notif['id']);
                            },
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isRead
                                        ? PulseColors.surfaceVariant
                                        : PulseColors.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isRead ? Icons.notifications_none : Icons.notifications_active,
                                    color: isRead ? PulseColors.textHint : PulseColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notif['title'],
                                        style: (isRead ? PulseTextStyles.body : PulseTextStyles.bodyBold)
                                            .copyWith(fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notif['message'],
                                        style: PulseTextStyles.caption,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        DateFormat('MMM d, h:mm a').format(
                                            DateTime.parse(notif['createdAt']).toLocal()),
                                        style: PulseTextStyles.caption.copyWith(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
