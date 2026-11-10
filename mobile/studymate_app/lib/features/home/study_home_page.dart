import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/models/study_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import '../courses/course_management_page.dart';
import '../events/events_calendar_page.dart';
import '../events/events_controller.dart';
import '../events/notifications_center_page.dart';
import '../profile/profile_page.dart';
import '../study/study_tools_page.dart';

class StudyHomePage extends StatefulWidget {
  const StudyHomePage({
    super.key,
    required this.controller,
    required this.user,
    required this.firebaseConfigured,
    required this.missingFirebaseOptions,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.onSignOut,
    this.onChangePassword,
    this.firebaseSetupError,
    this.onConnect,
  });

  final StudyController controller;
  final User? user;
  final bool firebaseConfigured;
  final String? firebaseSetupError;
  final List<String> missingFirebaseOptions;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final Future<void> Function()? onSignOut;
  final VoidCallback? onChangePassword;
  final VoidCallback? onConnect;

  @override
  State<StudyHomePage> createState() => _StudyHomePageState();
}

class _StudyHomePageState extends State<StudyHomePage> {
  int _selectedIndex = 0;
  _TaskFilter _taskFilter = _TaskFilter.all;
  late final EventsController _events = EventsController(
    widget.controller.api,
    userIdProvider: () => widget.user?.uid,
  );

  bool get _isWide => MediaQuery.sizeOf(context).width >= 800;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant StudyHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.uid != widget.user?.uid ||
        oldWidget.firebaseConfigured != widget.firebaseConfigured ||
        oldWidget.firebaseSetupError != widget.firebaseSetupError) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _events.dispose();
    super.dispose();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await widget.controller.loadForUser(widget.user);
      if (mounted && widget.user != null) _events.refreshUnread();
    });
  }

  Future<void> _openAgenda() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EventsCalendarPage(
          studyController: widget.controller,
          events: _events,
        ),
      ),
    );
    if (mounted) _events.refreshUnread();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotificationsCenterPage(
          studyController: widget.controller,
          events: _events,
        ),
      ),
    );
    if (mounted) _events.refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pages = [
          _buildDashboard(),
          _buildCoursesPage(),
          _buildTasksPage(),
          _buildNotesPage(),
          StudyToolsPage(
            controller: widget.controller,
            onRefresh: _refresh,
          ),
          ProfilePage(
            controller: widget.controller,
            user: widget.user,
            onSignOut: widget.onSignOut,
          ),
        ];
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leadingWidth: 58,
            leading: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                child: Icon(
                  Icons.school_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'StudyMate',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  widget.user?.email ?? 'Ton compagnon d’études',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            actions: [
              if (widget.user != null) ...[
                IconButton(
                  tooltip: 'Agenda',
                  onPressed: _openAgenda,
                  icon: const Icon(Icons.event_note_outlined),
                ),
                ListenableBuilder(
                  listenable: _events,
                  builder: (context, _) => IconButton(
                    tooltip: 'Notifications',
                    onPressed: _openNotifications,
                    icon: Badge(
                      isLabelVisible: _events.unreadCount > 0,
                      label: Text('${_events.unreadCount}'),
                      child: const Icon(Icons.notifications_outlined),
                    ),
                  ),
                ),
              ],
              IconButton(
                tooltip: 'Actualiser',
                onPressed: widget.controller.isLoading ? null : _refresh,
                icon: widget.controller.isLoading
                    ? const SizedBox.square(
                        dimension: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
              ),
              IconButton(
                tooltip: widget.isDarkMode
                    ? 'Activer le thème clair'
                    : 'Activer le thème sombre',
                onPressed: widget.onToggleTheme,
                icon: Icon(
                  widget.isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
              if (widget.user != null)
                PopupMenuButton<_AccountAction>(
                  tooltip: 'Compte',
                  onSelected: (action) {
                    switch (action) {
                      case _AccountAction.profile:
                        _selectPage(4);
                      case _AccountAction.changePassword:
                        widget.onChangePassword?.call();
                      case _AccountAction.signOut:
                        _signOut();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _AccountAction.profile,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.manage_accounts_outlined),
                        title: Text('Mon profil'),
                      ),
                    ),
                    if (widget.onChangePassword != null)
                      const PopupMenuItem(
                        value: _AccountAction.changePassword,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.lock_reset_outlined),
                          title: Text('Changer le mot de passe'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: _AccountAction.signOut,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.logout),
                        title: Text('Se déconnecter'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                if (_showConnectionBanner)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: _connectionBanner(),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 800;
                      return Row(
                        children: [
                          if (isWide) ...[
                            NavigationRail(
                              selectedIndex: _selectedIndex,
                              labelType: NavigationRailLabelType.all,
                              onDestinationSelected: _selectPage,
                              destinations: _railDestinations,
                            ),
                            const VerticalDivider(width: 1),
                          ],
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 880,
                                ),
                                child: IndexedStack(
                                  index: _selectedIndex,
                                  children: pages,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: _buildFloatingActionButton(),
          bottomNavigationBar: _isWide ? null : _buildBottomNavigationBar(),
        );
      },
    );
  }

  bool get _showConnectionBanner =>
      !widget.firebaseConfigured ||
      widget.firebaseSetupError != null ||
      widget.controller.errorMessage != null;

  Widget _connectionBanner() {
    final controller = widget.controller;
    final message = widget.firebaseSetupError ??
        (widget.firebaseConfigured
            ? controller.errorMessage
            : 'Mode aperçu : configure Firebase et démarre l’API pour '
                'synchroniser tes données.');
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.tertiaryContainer,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: colors.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message!,
                style: TextStyle(
                  color: colors.onTertiaryContainer,
                  fontSize: 12,
                ),
              ),
            ),
            if (widget.onConnect != null)
              TextButton(
                onPressed: widget.onConnect,
                child: const Text('Connexion'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (_selectedIndex == 1) {
      return FloatingActionButton.extended(
        heroTag: 'add-course',
        onPressed: _addCourse,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter un cours'),
      );
    }
    if (_selectedIndex == 2) {
      return FloatingActionButton.extended(
        heroTag: 'add-task',
        onPressed: _addTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle tâche'),
      );
    }
    if (_selectedIndex == 3) {
      return FloatingActionButton.extended(
        heroTag: 'add-note',
        onPressed: _addNote,
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Nouvelle note'),
      );
    }
    return const SizedBox.shrink();
  }

  NavigationBar _buildBottomNavigationBar() => NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'Cours',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: 'Tâches',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style_rounded),
            label: 'Réviser',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      );

  List<NavigationRailDestination> get _railDestinations => const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Accueil'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.school_outlined),
          selectedIcon: Icon(Icons.school_rounded),
          label: Text('Cours'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.checklist_outlined),
          selectedIcon: Icon(Icons.checklist_rounded),
          label: Text('Tâches'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book_rounded),
          label: Text('Notes'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.style_outlined),
          selectedIcon: Icon(Icons.style_rounded),
          label: Text('Réviser'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Profil'),
        ),
      ];

  void _selectPage(int index) => setState(() => _selectedIndex = index);

  Future<void> _signOut() async {
    try {
      await widget.onSignOut?.call();
    } on GoogleSignInException catch (error) {
      if (mounted) {
        _showMessage(error.description ?? 'La déconnexion Google a échoué.');
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showMessage('La déconnexion a échoué (${error.code}).');
    }
  }

  Future<void> _refresh() async {
    if (widget.user == null) {
      _showMessage('Connecte-toi pour synchroniser les données.');
      return;
    }
    await widget.controller.loadForUser(widget.user);
    _events.refreshUnread();
    if (widget.controller.errorMessage case final message?) {
      _showMessage(message);
    }
  }

  Widget _pageList(List<Widget> children, {double top = 14}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, top, 20, 100),
      children: children,
    );
  }

  Widget _buildDashboard() {
    final now = DateTime.now();
    final date =
        '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}';
    final courses = widget.controller.courses;
    final course = courses.isEmpty ? null : courses.first;
    final previewTasks = widget.controller.tasks.take(2).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: _pageList([
        Text(
          date.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.user?.displayName?.isNotEmpty == true
              ? 'Bonjour, ${widget.user!.displayName} 👋'
              : 'Bonjour, étudiant·e 👋',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Un petit pas aujourd’hui, une grande réussite demain.',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        _buildProgressCard(),
        const SizedBox(height: 18),
        _sectionTitle(context, 'Mes cours', 'Tout voir', () => _selectPage(1)),
        const SizedBox(height: 8),
        if (course == null)
          _emptyCard(
            icon: Icons.school_outlined,
            title: 'Aucun cours pour le moment',
            action: 'Ajouter un cours',
            onPressed: () {
              _selectPage(1);
              _addCourse();
            },
          )
        else
          _courseCard(course),
        const SizedBox(height: 18),
        _sectionTitle(
          context,
          'Mes tâches',
          'Tout voir',
          () => _selectPage(2),
        ),
        const SizedBox(height: 8),
        if (previewTasks.isEmpty)
          _emptyCard(
            icon: Icons.task_alt_rounded,
            title: 'Ta liste de tâches est vide',
            action: 'Ajouter une tâche',
            onPressed: () {
              _selectPage(2);
              _addTask();
            },
          )
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < previewTasks.length; index++) ...[
                  if (index > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _taskTile(previewTasks[index]),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        const _InfoCard(
          icon: Icons.auto_awesome_rounded,
          title: 'Ton conseil du jour',
          body: 'Révise 25 minutes, puis accorde-toi une petite pause.',
        ),
      ]),
    );
  }

  Widget _buildProgressCard() {
    final tasks = widget.controller.tasks;
    final total = tasks.length;
    final completed = widget.controller.completedTaskCount;
    final progress = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6750A4), Color(0xFF8872C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Ta journée en bref',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.auto_awesome_rounded, color: Colors.white),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 26,
            runSpacing: 14,
            children: [
              _progressStat(Icons.task_alt_rounded, '$total', 'tâches'),
              _progressStat(
                Icons.menu_book_rounded,
                '${widget.controller.courses.length}',
                'cours',
              ),
              _progressStat(
                Icons.check_circle_outline_rounded,
                '$completed',
                'terminées',
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.28),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed sur $total tâches terminées',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressStat(IconData icon, String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white70),
              const SizedBox(width: 5),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      );

  Widget _buildCoursesPage() => CourseManagementPage(
        controller: widget.controller,
        onRefresh: _refresh,
      );

  Widget _buildTasksPage() {
    final tasks = switch (_taskFilter) {
      _TaskFilter.all => widget.controller.tasks,
      _TaskFilter.pending =>
        widget.controller.tasks.where((task) => !task.isCompleted).toList(),
      _TaskFilter.completed =>
        widget.controller.tasks.where((task) => task.isCompleted).toList(),
    };
    final remaining =
        widget.controller.tasks.where((task) => !task.isCompleted).length;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: _pageList([
        _pageHeading(
          'Mes tâches',
          '$remaining tâche${remaining == 1 ? '' : 's'} à terminer',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            for (final filter in _TaskFilter.values)
              ChoiceChip(
                label: Text(filter.label),
                selected: _taskFilter == filter,
                onSelected: (_) => setState(() => _taskFilter = filter),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          _emptyCard(
            icon: Icons.task_alt_rounded,
            title: _taskFilter == _TaskFilter.completed
                ? 'Aucune tâche terminée pour le moment'
                : 'Ta liste est vide',
            action: 'Ajouter une tâche',
            onPressed: _addTask,
          )
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < tasks.length; index++) ...[
                  if (index > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _taskTile(tasks[index]),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        const _InfoCard(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Astuce',
          body: 'Commence par une petite tâche pour lancer ta dynamique.',
        ),
      ]),
    );
  }

  Widget _buildNotesPage() => RefreshIndicator(
        onRefresh: _refresh,
        child: _pageList([
          _pageHeading(
            'Mes notes',
            'Tes idées et tes révisions au même endroit.',
          ),
          const SizedBox(height: 16),
          if (widget.controller.notes.isEmpty)
            _emptyCard(
              icon: Icons.note_add_outlined,
              title: 'Aucune note pour le moment',
              action: 'Créer une note',
              onPressed: _addNote,
            )
          else
            for (final note in widget.controller.notes) ...[
              _noteCard(note),
              const SizedBox(height: 10),
            ],
        ]),
      );

  Widget _pageHeading(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );

  Widget _courseCard(StudyCourse course) => Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: Icon(
              Icons.menu_book_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            course.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              if (course.code?.isNotEmpty == true) course.code!,
              if (course.professor?.isNotEmpty == true) course.professor!,
              if (course.room?.isNotEmpty == true) course.room!,
            ].join(' · ').isEmpty
                ? 'Cours'
                : [
                    if (course.code?.isNotEmpty == true) course.code!,
                    if (course.professor?.isNotEmpty == true) course.professor!,
                    if (course.room?.isNotEmpty == true) course.room!,
                  ].join(' · '),
          ),
        ),
      );

  Widget _taskTile(StudyTask task) => CheckboxListTile(
        value: task.isCompleted,
        onChanged: widget.controller.isLoading
            ? null
            : (value) => _runAction(
                  () => widget.controller.toggleTask(task, value ?? false),
                ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
        ),
        subtitle: Text(
          task.description?.isNotEmpty == true
              ? task.description!
              : 'Priorité ${_priorityLabel(task.priority)}',
        ),
      );

  Widget _noteCard(StudyNote note) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: Icon(
              Icons.description_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(note.title,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              note.content.isEmpty ? 'Note sans contenu' : note.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          isThreeLine: true,
          trailing: IconButton(
            tooltip: 'Supprimer la note',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _confirmDeleteNote(note),
          ),
        ),
      );

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String action,
    required VoidCallback onPressed,
  }) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                icon,
                size: 34,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(title, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.add_rounded),
                label: Text(action),
              ),
            ],
          ),
        ),
      );

  Future<void> _addTask() async {
    final title = await _textDialog(
      title: 'Nouvelle tâche',
      fieldLabel: 'Que veux-tu faire ?',
      action: 'Ajouter',
    );
    if (title == null || !mounted) return;
    await _runAction(() => widget.controller.addTask(title));
  }

  Future<void> _addCourse() async {
    final fields = await _fieldsDialog(
      title: 'Ajouter un cours',
      fields: const [
        ('title', 'Nom du cours', true),
        ('code', 'Code (facultatif)', false),
        ('professor', 'Enseignant·e (facultatif)', false),
        ('room', 'Salle (facultatif)', false),
      ],
    );
    if (fields == null || !mounted) return;
    await _runAction(
      () => widget.controller.addCourse(
        title: fields['title']!,
        code: _optional(fields['code']),
        professor: _optional(fields['professor']),
        room: _optional(fields['room']),
      ),
    );
  }

  Future<void> _addNote() async {
    final fields = await _fieldsDialog(
      title: 'Nouvelle note',
      fields: const [
        ('title', 'Titre', true),
        ('content', 'Contenu', false),
      ],
      multilineField: 'content',
    );
    if (fields == null || !mounted) return;
    await _runAction(
      () => widget.controller.addNote(
        title: fields['title']!,
        content: fields['content'] ?? '',
      ),
    );
  }

  Future<void> _confirmDeleteNote(StudyNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette note ?'),
        content: Text('« ${note.title} » sera supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _runAction(() => widget.controller.deleteNote(note));
    }
  }

  Future<String?> _textDialog({
    required String title,
    required String fieldLabel,
    required String action,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: fieldLabel,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: Text(action),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<Map<String, String>?> _fieldsDialog({
    required String title,
    required List<(String, String, bool)> fields,
    String? multilineField,
  }) async {
    final controllers = {
      for (final field in fields) field.$1: TextEditingController(),
    };
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < fields.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  TextFormField(
                    controller: controllers[fields[index].$1],
                    autofocus: index == 0,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: fields[index].$1 == multilineField ? 3 : 1,
                    maxLines: fields[index].$1 == multilineField ? 5 : 1,
                    decoration: InputDecoration(
                      labelText: fields[index].$2,
                      border: const OutlineInputBorder(),
                    ),
                    validator: fields[index].$3
                        ? (value) => value == null || value.trim().isEmpty
                            ? 'Ce champ est requis.'
                            : null
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                controllers.map(
                  (key, controller) => MapEntry(key, controller.text.trim()),
                ),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) _showMessage('Enregistré.');
    } on StudyMateApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _optional(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String _priorityLabel(String priority) => switch (priority) {
        'high' => 'haute',
        'low' => 'basse',
        _ => 'moyenne',
      };

  static Widget _sectionTitle(
    BuildContext context,
    String title,
    String action,
    VoidCallback onPressed,
  ) =>
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          TextButton(onPressed: onPressed, child: Text(action)),
        ],
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AccountAction { profile, changePassword, signOut }

enum _TaskFilter {
  all('Toutes'),
  pending('À faire'),
  completed('Terminées');

  const _TaskFilter(this.label);
  final String label;
}

const _weekdays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];
