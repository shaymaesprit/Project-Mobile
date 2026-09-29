import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.name, required this.coursesCount, required this.tasksCount, required this.onSignOut});
  final String name; final int coursesCount; final int tasksCount; final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))]), child: Row(children: [
            Container(width: 64, height: 64, decoration: const BoxDecoration(color: Color(0xFF006D77), borderRadius: BorderRadius.all(Radius.circular(18))), child: const Icon(Icons.person, color: Colors.white, size: 32)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 4), const Text('Computer Science • 3rd year', style: TextStyle(color: Color(0xFF64748B)))])),
          ])),
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _ProfileMetric(label: 'Courses', value: '$coursesCount'),
            _ProfileMetric(label: 'Tasks', value: '$tasksCount'),
            _ProfileMetric(label: 'Progress', value: '81%'),
          ])),
          const SizedBox(height: 18),
          ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Account settings'), trailing: const Icon(Icons.chevron_right_rounded)),
          ListTile(leading: const Icon(Icons.notifications_none_rounded), title: const Text('Notifications'), trailing: const Icon(Icons.chevron_right_rounded)),
          ListTile(leading: const Icon(Icons.lock_outline_rounded), title: const Text('Privacy'), trailing: const Icon(Icons.chevron_right_rounded)),
          const Spacer(),
          FilledButton.icon(onPressed: onSignOut, icon: const Icon(Icons.logout_rounded), label: const Text('Sign out'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444), minimumSize: const Size.fromHeight(52))),
        ]),
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.label, required this.value});
  final String label; final String value;
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))]);
}
