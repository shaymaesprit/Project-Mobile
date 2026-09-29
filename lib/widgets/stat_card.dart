import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.accent});
  final String label; final String value; final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(color: accent.withOpacity(0.09), borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: accent, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Color(0xFF64748B))),
    ]),
  );
}
