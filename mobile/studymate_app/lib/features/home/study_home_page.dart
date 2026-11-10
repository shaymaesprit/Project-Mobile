import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/study_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import '../courses/course_management_page.dart';
import '../courses/timetable_page.dart';
import '../events/events_calendar_page.dart';
import '../events/events_controller.dart';
import '../events/notifications_center_page.dart';
import '../insights/learning_insights_page.dart';
import '../profile/profile_page.dart';
import '../profile/user_avatar.dart';
import '../study/study_tools_page.dart';
import 'dashboard_widgets.dart';
import 'note_detail_page.dart';
import 'note_wikipedia_page.dart';
import 'task_planner_page.dart';

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
    sync: widget.controller.sync,
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

  Future<void> _openTimetable() => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TimetablePage(api: widget.controller.api),
        ),
      );

  Future<void> _openPlanner() => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TaskPlannerPage(
            controller: widget.controller,
            onTasksChanged: _refresh,
          ),
        ),
      );

  Future<void> _openWikipedia(StudyNote note) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              NoteWikipediaPage(controller: widget.controller, note: note),
        ),
      );

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
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppGradients.brand,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
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
              if (widget.controller.sync case final sync?)
                ListenableBuilder(
                  listenable: sync,
                  builder: (context, _) {
                    if (sync.pendingCount == 0) return const SizedBox.shrink();
                    return IconButton(
                      tooltip: sync.isOnline
                          ? '${sync.pendingCount} modification(s) en cours d’envoi'
                          : 'Hors ligne · ${sync.pendingCount} modification(s) en attente',
                      onPressed: sync.isSyncing
                          ? null
                          : () async {
                              final done = await sync.flush();
                              if (!mounted) return;
                              _showMessage(
                                done
                                    ? 'Tout est synchronisé.'
                                    : 'Toujours hors ligne : nouvel essai automatique bientôt.',
                              );
                            },
                      icon: Badge(
                        label: Text('${sync.pendingCount}'),
                        backgroundColor: AppPalette.amber,
                        child: Icon(
                          sync.isSyncing
                              ? Icons.cloud_sync_rounded
                              : Icons.cloud_off_rounded,
                        ),
                      ),
                    );
                  },
                ),
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
                  padding: EdgeInsets.zero,
                  // Photo de profil (ou initiales) à la place des trois points.
                  icon: UserAvatar(
                    photoUrl: widget.controller.userProfile?.photoUrl ?? widget.user?.photoURL,
                    name: widget.controller.userProfile?.displayName ??
                        widget.user?.displayName ??
                        widget.user?.email,
                    radius: 15,
                    ring: true,
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case _AccountAction.profile:
                        _selectPage(5);
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
    // Accueil : petite icône de l'assistant IA.
    if (_selectedIndex == 0 && widget.user != null) {
      return Tooltip(
        message: 'Analyses d’apprentissage et assistant IA',
        child: Material(
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: AppPalette.violet.withValues(alpha: 0.5),
          child: Ink(
            width: 52,
            height: 52,
            decoration: const ShapeDecoration(
              shape: CircleBorder(),
              gradient: AppGradients.brand,
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      LearningInsightsPage(controller: widget.controller),
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
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
    // Modifications faites hors ligne pas encore envoyées : on prévient.
    final sync = widget.controller.sync;
    if (sync != null && sync.pendingCount > 0) {
      await sync.flush();
      if (!mounted) return;
      if (sync.pendingCount > 0) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.cloud_off_rounded),
            title: const Text('Modifications non synchronisées'),
            content: Text(
              '${sync.pendingCount} modification(s) faite(s) hors ligne '
              'n’ont pas encore été envoyées. Si tu te déconnectes maintenant, '
              'elles seront perdues.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Rester connecté'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Se déconnecter quand même'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }
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
    final controller = widget.controller;
    final courses = controller.courses;
    final pending = controller.tasks.where((t) => !t.isCompleted).toList()
      ..sort((a, b) {
        final da = a.deadline, db = b.deadline;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    final focus = pending.isEmpty ? null : pending.first;
    final previewTasks = pending.skip(1).take(3).toList();

    var step = 0;
    Widget reveal(Widget child) => child
        .animate(delay: (70 * step++).ms)
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: _pageList([
        reveal(
          DashboardHero(
            name: widget.user?.displayName,
            dateLabel: date.toUpperCase(),
            completed: controller.completedTaskCount,
            total: controller.tasks.length,
            courseCount: courses.length,
            noteCount: controller.notes.length,
          ),
        ),
        const SizedBox(height: 18),
        reveal(
          Row(
            children: [
              Expanded(
                child: QuickAction(
                  icon: Icons.calendar_view_week_rounded,
                  label: 'Emploi du t.',
                  color: AppPalette.sky,
                  onTap: _openTimetable,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickAction(
                  icon: Icons.style_rounded,
                  label: 'Réviser',
                  color: AppPalette.violet,
                  onTap: () => _selectPage(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickAction(
                  icon: Icons.auto_graph_rounded,
                  label: 'Planning',
                  color: AppPalette.coral,
                  onTap: _openPlanner,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickAction(
                  icon: Icons.event_note_rounded,
                  label: 'Agenda',
                  color: AppPalette.mint,
                  onTap: _openAgenda,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (focus != null) ...[
          reveal(
            FocusTaskCard(
              task: focus,
              remaining: pending.length,
              onDone: controller.isLoading
                  ? null
                  : () => _runAction(() => controller.toggleTask(focus, true)),
            ),
          ),
          const SizedBox(height: 18),
        ],
        reveal(
          _sectionTitle(
              context, 'Mes cours', 'Tout voir', () => _selectPage(1)),
        ),
        const SizedBox(height: 6),
        if (courses.isEmpty)
          reveal(
            _emptyCard(
              icon: Icons.school_outlined,
              title: 'Aucun cours pour le moment',
              action: 'Ajouter un cours',
              onPressed: () {
                _selectPage(1);
                _addCourse();
              },
            ),
          )
        else
          reveal(
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: courses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, index) => CourseTile(
                  course: courses[index],
                  onTap: () => _selectPage(1),
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        reveal(
          _sectionTitle(
            context,
            focus == null ? 'Mes tâches' : 'Ensuite',
            'Tout voir',
            () => _selectPage(2),
          ),
        ),
        const SizedBox(height: 6),
        if (focus == null)
          reveal(
            _emptyCard(
              icon: Icons.celebration_rounded,
              title: controller.tasks.isEmpty
                  ? 'Ta liste de tâches est vide'
                  : 'Tout est terminé, bravo !',
              action: 'Ajouter une tâche',
              onPressed: _addTask,
            ),
          )
        else if (previewTasks.isNotEmpty)
          reveal(
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
          ),
        const SizedBox(height: 18),
        reveal(const DailyTipCard()),
      ]),
    );
  }

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
        _FeatureCard(
          icon: Icons.auto_graph_rounded,
          color: AppPalette.coral,
          title: 'Planning intelligent',
          subtitle:
              'Priorise tes tâches et les place dans tes créneaux libres.',
          onTap: _openPlanner,
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
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          // Toucher la note ouvre son contenu complet.
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => NoteDetailPage(controller: widget.controller, note: note),
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppPalette.accentFor(note.id).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.description_rounded,
              color: AppPalette.accentFor(note.id),
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
          trailing: PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (action) => action == 'wiki'
                ? _openWikipedia(note)
                : _confirmDeleteNote(note),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'wiki',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.travel_explore_rounded),
                  title: Text('Compléter avec Wikipédia'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Supprimer'),
                ),
              ),
            ],
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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
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
    return showDialog<String>(
      context: context,
      builder: (context) => _DialogControllers(
        keys: const ['value'],
        builder: (context, controllers) {
          final controller = controllers['value']!;
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: fieldLabel,
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context, value.trim());
                }
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
          );
        },
      ),
    );
  }

  Future<Map<String, String>?> _fieldsDialog({
    required String title,
    required List<(String, String, bool)> fields,
    String? multilineField,
  }) async {
    final formKey = GlobalKey<FormState>();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _DialogControllers(
        keys: [for (final field in fields) field.$1],
        builder: (context, controllers) => AlertDialog(
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
      ),
    );
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

/// Carte d'accès à une fonctionnalité (planning, emploi du temps…).
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      );
}

/// Possède les champs d'une boîte de dialogue et ne les libère qu'une fois
/// la boîte réellement retirée (après son animation de fermeture).
class _DialogControllers extends StatefulWidget {
  const _DialogControllers({required this.keys, required this.builder});

  final List<String> keys;
  final Widget Function(
    BuildContext context,
    Map<String, TextEditingController> controllers,
  ) builder;

  @override
  State<_DialogControllers> createState() => _DialogControllersState();
}

class _DialogControllersState extends State<_DialogControllers> {
  late final Map<String, TextEditingController> _controllers = {
    for (final key in widget.keys) key: TextEditingController(),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controllers);
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
