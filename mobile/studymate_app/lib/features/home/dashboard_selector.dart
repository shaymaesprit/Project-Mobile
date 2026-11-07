import 'package:flutter/material.dart';
import '../../data/models/study_models.dart';
import 'modern_dashboard.dart';
import 'creative_dashboard.dart';

enum DashboardStyle { modern, creative }

class DashboardSelector extends StatefulWidget {
  const DashboardSelector({
    super.key,
    required this.userName,
    required this.totalTasks,
    required this.completedTasks,
    required this.courses,
    required this.tasks,
    required this.onCoursesTap,
    required this.onTasksTap,
    required this.onAddCourse,
    required this.onAddTask,
    required this.onToggleTask,
    required this.onNotesTab,
    required this.onStudyTab,
    this.initialStyle = DashboardStyle.creative,
  });

  final String userName;
  final int totalTasks;
  final int completedTasks;
  final List<StudyCourse> courses;
  final List<StudyTask> tasks;
  final VoidCallback onCoursesTap;
  final VoidCallback onTasksTap;
  final VoidCallback onAddCourse;
  final VoidCallback onAddTask;
  final void Function(StudyTask, bool) onToggleTask;
  final VoidCallback onNotesTab;
  final VoidCallback onStudyTab;
  final DashboardStyle initialStyle;

  @override
  State<DashboardSelector> createState() => _DashboardSelectorState();
}

class _DashboardSelectorState extends State<DashboardSelector> {
  late DashboardStyle _currentStyle;

  @override
  void initState() {
    super.initState();
    _currentStyle = widget.initialStyle;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dashboard content
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _currentStyle == DashboardStyle.modern
              ? ModernDashboard(
                  key: const ValueKey('modern'),
                  userName: widget.userName,
                  totalTasks: widget.totalTasks,
                  completedTasks: widget.completedTasks,
                  courses: widget.courses,
                  tasks: widget.tasks,
                  onCoursesTap: widget.onCoursesTap,
                  onTasksTap: widget.onTasksTap,
                  onAddCourse: widget.onAddCourse,
                  onAddTask: widget.onAddTask,
                  onToggleTask: widget.onToggleTask,
                )
              : CreativeDashboard(
                  key: const ValueKey('creative'),
                  userName: widget.userName,
                  totalTasks: widget.totalTasks,
                  completedTasks: widget.completedTasks,
                  courses: widget.courses,
                  tasks: widget.tasks,
                  onCoursesTap: widget.onCoursesTap,
                  onTasksTap: widget.onTasksTap,
                  onAddCourse: widget.onAddCourse,
                  onAddTask: widget.onAddTask,
                  onToggleTask: widget.onToggleTask,
                  onNotesTab: widget.onNotesTab,
                  onStudyTab: widget.onStudyTab,
                ),
        ),

        // Style switcher button
        Positioned(
          right: 16,
          bottom: 88,
          child: FloatingActionButton.small(
            heroTag: 'style-switcher',
            onPressed: () {
              setState(() {
                _currentStyle = _currentStyle == DashboardStyle.modern
                    ? DashboardStyle.creative
                    : DashboardStyle.modern;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _currentStyle == DashboardStyle.modern
                        ? '✨ Style Moderne activé'
                        : '🎨 Style Créatif activé',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Changer de style',
            child: Icon(
              _currentStyle == DashboardStyle.modern
                  ? Icons.palette_outlined
                  : Icons.auto_awesome_outlined,
            ),
          ),
        ),
      ],
    );
  }
}
