import 'package:flutter/material.dart';

class NeumorphicCard extends StatelessWidget {
  const NeumorphicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.isPressed = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final bool isPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E5EC);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: isDark ? Colors.black54 : Colors.black12,
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
              ]
            : [
                BoxShadow(
                  color: isDark ? Colors.black87 : Colors.white,
                  offset: const Offset(-6, -6),
                  blurRadius: 12,
                ),
                BoxShadow(
                  color: isDark ? Colors.black54 : Colors.black12,
                  offset: const Offset(6, 6),
                  blurRadius: 12,
                ),
              ],
      ),
      child: child,
    );
  }
}
