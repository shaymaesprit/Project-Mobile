import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.trailing});
  final String title; final String trailing;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), Text(trailing, style: const TextStyle(color: Color(0xFF006D77), fontWeight: FontWeight.w600))]);
}
