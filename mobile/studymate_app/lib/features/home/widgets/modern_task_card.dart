import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ModernTaskCard extends StatelessWidget {
  const ModernTaskCard({
    super.key,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.priority,
    required this.onChanged,
    this.delay = Duration.zero,
  });

  final String title;
  final String? description;
  final bool isCompleted;
  final String priority;
  final ValueChanged<bool> onChanged;
  final Duration delay;

  Color _getPriorityColor(BuildContext context) {
    return switch (priority.toLowerCase()) {
      'high' => Colors.red,
      'medium' => Colors.orange,
      _ => Colors.green,
    };
  }

  IconData _getPriorityIcon() {
    return switch (priority.toLowerCase()) {
      'high' => Icons.priority_high_rounded,
      'medium' => Icons.remove_rounded,
      _ => Icons.arrow_downward_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCompleted
              ? Theme.of(context).colorScheme.outline.withOpacity(0.2)
              : _getPriorityColor(context).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => onChanged(!isCompleted),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: isCompleted
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5)
                                : null,
                          ),
                    ),
                    if (description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!isCompleted)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getPriorityIcon(),
                    size: 16,
                    color: _getPriorityColor(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.2, end: 0, duration: 400.ms);
  }
}
