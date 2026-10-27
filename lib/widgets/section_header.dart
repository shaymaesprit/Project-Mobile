import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(
      {super.key, required this.title, required this.trailing, this.onPressed});
  final String title;
  final String trailing;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(
          child: Text(title,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis),
        ),
        TextButton(onPressed: onPressed, child: Text(trailing)),
      ]);
}
