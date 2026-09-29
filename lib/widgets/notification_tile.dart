import 'package:flutter/material.dart';
import '../models/study_models.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.notification});
  final StudyNotification notification;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: notification.read ? Colors.transparent : const Color(0xFF83C5BE))),
    child: Row(children: [
      Container(width: 42, height: 42, decoration: const BoxDecoration(color: Color(0xFFEDF6F9), borderRadius: BorderRadius.all(Radius.circular(12))), child: const Icon(Icons.notifications_active_outlined, color: Color(0xFF006D77))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(notification.title, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 4), Text(notification.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B)))])),
      const SizedBox(width: 8),
      Text('${notification.dateTime.hour}:${notification.dateTime.minute.toString().padLeft(2,'0')}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
    ]),
  );
}
