import 'package:flutter/material.dart';
import '../models/study_models.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.notifications});

  final List<StudyNotification> notifications;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: notifications.isEmpty
            ? const Center(child: Text('No notifications yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) =>
                    NotificationTile(notification: notifications[index]),
              ),
      ),
    );
  }
}
