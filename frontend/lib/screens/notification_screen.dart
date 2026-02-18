import 'package:flutter/material.dart';
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
        final notifications = await ApiService.getNotifications(user['id']);
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final isRead = notification['isRead'] == 1;
                    return Dismissible(
                      key: Key(notification['id'].toString()),
                      background: Container(
                        color: Colors.blue,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                         child: const Icon(Icons.mark_email_read, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        _markAsRead(notification['id']);
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: isRead ? Colors.white : Colors.blue.withValues(alpha: 0.05),
                        child: ListTile(
                          leading: Icon(
                            isRead ? Icons.notifications_none : Icons.notifications_active,
                            color: isRead ? Colors.grey : Colors.blue,
                          ),
                          title: Text(
                            notification['title'],
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notification['message']),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM d, h:mm a').format(DateTime.parse(notification['createdAt']).toLocal()),
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          onTap: () {
                            if (!isRead) _markAsRead(notification['id']);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
