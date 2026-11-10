import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/ai_models.dart';
import '../../data/services/studymate_api.dart';
import '../../state/study_controller.dart';
import 'ai_consent.dart';
import 'learning_profile_onboarding_page.dart';

const _weekdays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

String _level(String? value) => switch (value) {
      'low' => 'faible',
      'medium' => 'moyen',
      'high' => 'élevé',
      _ => value ?? '—',
    };

/// Explainable ML results (M1-M4) and AI assistant (consent-gated).
class LearningInsightsPage extends StatefulWidget {
  const LearningInsightsPage({super.key, required this.controller});

  final StudyController controller;

  @override
  State<LearningInsightsPage> createState() => _LearningInsightsPageState();
}

class _LearningInsightsPageState extends State<LearningInsightsPage> {
  StudyMateApi get _api => widget.controller.api;

  AiConsent? _consent;
  MlOverview? _ml;
  List<AiRecommendation> _recommendations = const [];
  AiInsight? _insight;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  DateTime? _sessionStart;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final consent = await _api.getAiConsent();
      final ml = await _api.getMlOverview();
      var recommendations = const <AiRecommendation>[];
      AiInsight? insight;
      if (consent.granted) {
        recommendations = await _api.getAiRecommendations();
        final insights = await _api.getAiInsights();
        insight = insights.isEmpty ? null : insights.first;
      }
      if (!mounted) return;
      setState(() {
        _consent = consent;
        _ml = ml;
        _recommendations = recommendations;
        _insight = insight;
      });
    } on StudyMateApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on StudyMateApiException catch (error) {
      _snack(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _grantConsent() => _run(() async {
        final consent = await _api.setAiConsent(true);
        await widget.controller.refreshProfile();
        if (mounted) setState(() => _consent = consent);
        await _load();
      });

  Future<void> _generate() => _run(() async {
        final items = await _api.generateAiRecommendations();
        if (mounted) setState(() => _recommendations = items);
      });

  Future<void> _analyze() => _run(() async {
        final insight = await _api.analyzeAiProfile();
        if (mounted) setState(() => _insight = insight);
      });

  Future<void> _decide(
    AiRecommendation item,
    String status, {
    String? title,
    String? description,
  }) =>
      _run(() async {
        final updated = await _api.updateAiRecommendation(
          item.id,
          status: status,
          title: title,
          description: description,
        );
        if (!mounted) return;
        setState(() {
          _recommendations = [
            for (final r in _recommendations) r.id == updated.id ? updated : r,
          ];
        });
      });

  Future<void> _modify(AiRecommendation item) async {
    final title = TextEditingController(text: item.title);
    final description = TextEditingController(text: item.description);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier la recommandation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              TextField(
                controller: description,
                maxLength: 2000,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    final newTitle = title.text.trim();
    final newDescription = description.text.trim();
    title.dispose();
    description.dispose();
    if (confirmed != true) return;
    if (newTitle.length < 3 || newDescription.length < 3) {
      _snack('Le titre et la description doivent contenir au moins 3 caractères.');
      return;
    }
    await _decide(
      item,
      'modified',
      title: newTitle,
      description: newDescription,
    );
  }

  Future<void> _openChat() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AiChatSheet(api: _api),
    );
  }

  void _toggleSession() {
    final start = _sessionStart;
    if (start == null) {
      setState(() {
        _sessionStart = DateTime.now();
        _elapsed = Duration.zero;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        final started = _sessionStart;
        if (started != null && mounted) {
          setState(() => _elapsed = DateTime.now().difference(started));
        }
      });
      return;
    }
    _ticker?.cancel();
    final end = DateTime.now();
    setState(() => _sessionStart = null);
    if (end.difference(start).inSeconds < 60) {
      _snack('Session trop courte (moins d’une minute) : non enregistrée.');
      return;
    }
    _askFocusAndSave(start, end);
  }

  Future<void> _askFocusAndSave(DateTime start, DateTime end) async {
    final rating = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Concentration pendant la session'),
        children: [
          for (var i = 1; i <= 5; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text('$i / 5'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Ne pas évaluer'),
          ),
        ],
      ),
    );
    if (rating == null) return;
    await _run(() async {
      await _api.createStudySession(
        startedAt: start,
        endedAt: end,
        focusRating: rating == 0 ? null : rating,
      );
      _snack('Session enregistrée.');
      final ml = await _api.getMlOverview();
      if (mounted) setState(() => _ml = ml);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Analyses d’apprentissage'),
          actions: [
            IconButton(
              tooltip: 'Questionnaire d’apprentissage',
              icon: const Icon(Icons.tune),
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => LearningProfileOnboardingPage(
                      controller: widget.controller,
                    ),
                  ),
                );
                if (saved == true) await _load();
              },
            ),
            IconButton(
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        _sessionCard(),
                        if (_ml != null) ..._mlCards(_ml!),
                        _aiSection(),
                      ],
                    ),
                  ),
      );

  Widget _card(String title, List<Widget> children, {IconData? icon}) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  Widget _bullets(Iterable<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• $item'),
            ),
        ],
      );

  Widget _sessionCard() {
    final running = _sessionStart != null;
    String two(int n) => n.toString().padLeft(2, '0');
    final clock =
        '${two(_elapsed.inHours)}:${two(_elapsed.inMinutes % 60)}:${two(_elapsed.inSeconds % 60)}';
    return _card(
      'Session d’étude',
      [
        const Text(
          'Les sessions enregistrées servent à calculer ton comportement '
          'd’étude et tes recommandations.',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _toggleSession,
              icon: Icon(running ? Icons.stop : Icons.play_arrow),
              label: Text(running ? 'Terminer' : 'Démarrer'),
            ),
            const SizedBox(width: 16),
            if (running)
              Text(clock, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ],
      icon: Icons.timer_outlined,
    );
  }

  List<Widget> _mlCards(MlOverview ml) {
    final performance = ml.performance;
    final behavior = ml.behavior;
    final recommendations = ml.recommendations;
    final profile = ml.profile;
    return [
      _card(
        'Performance estimée',
        [
          if (ml.performanceAvailable) ...[
            Text(
              '${(performance['predicted_score_percent'] as num).toStringAsFixed(0)} %'
              ' (entre ${(performance['range_low'] as num).toStringAsFixed(0)}'
              ' et ${(performance['range_high'] as num).toStringAsFixed(0)} %)',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Estimation indicative, confiance '
              '${performance['confidence'] == 'medium' ? 'moyenne' : 'faible'}.',
            ),
            const SizedBox(height: 8),
            if ((performance['risk_indicators'] as List? ?? const []).isNotEmpty)
              _bullets([
                for (final risk in performance['risk_indicators'] as List)
                  '${(risk as Map)['message']} (niveau ${_level(risk['level'] as String?)})',
              ]),
            if ((performance['explanation'] as List? ?? const []).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Pourquoi ?',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              _bullets([
                for (final item in performance['explanation'] as List)
                  (item as Map)['text'] as String,
              ]),
            ],
          ] else ...[
            const Text('Données insuffisantes pour estimer ta performance.'),
            _bullets(ml.stringList(performance, 'missing_data')),
          ],
        ],
        icon: Icons.insights_outlined,
      ),
      _card(
        'Comportement d’étude',
        [
          if (ml.behaviorAvailable) ...[
            Text(
              '${behavior['sessions_count']} sessions sur '
              '${behavior['window_days']} jours',
            ),
            if (behavior['total_study_hours'] != null)
              Text(
                'Total : ${(behavior['total_study_hours'] as num).toStringAsFixed(1)} h',
              ),
            if (behavior['average_session_minutes'] != null)
              Text(
                'Durée moyenne : ${(behavior['average_session_minutes'] as num).toStringAsFixed(0)} min',
              ),
            if (behavior['productivity_score'] != null)
              Text(
                'Score de productivité : ${(behavior['productivity_score'] as num).toStringAsFixed(0)}',
              ),
            const SizedBox(height: 6),
            _bullets(ml.stringList(behavior, 'suggestions')),
          ] else ...[
            const Text('Pas assez de sessions pour analyser ton comportement.'),
            _bullets(ml.stringList(behavior, 'missing_data')),
          ],
        ],
        icon: Icons.query_stats,
      ),
      _card(
        'Profil d’apprentissage',
        [
          if (profile['status'] != 'ok')
            const Text('Complète le questionnaire pour affiner ton profil.'),
          if (profile['typical_session_minutes'] != null)
            Text(
              'Session typique : ${profile['typical_session_minutes']} min',
            ),
          for (final period in profile['preferred_periods'] as List? ?? const [])
            Text(
              '${_period((period as Map)['period'] as String)} : '
              '${((period['share'] as num) * 100).toStringAsFixed(0)} %',
            ),
          for (final item
              in profile['difficulty_indicators'] as List? ?? const [])
            Text(
              '${(item as Map)['subject']} : difficulté ${_level(item['level'] as String?)}',
            ),
          _bullets(ml.stringList(profile, 'recommendations')),
        ],
        icon: Icons.person_search_outlined,
      ),
      _card(
        'Recommandations',
        [
          if (ml.coldStart)
            const Text(
              'Recommandations génériques : elles s’affineront avec tes données.',
            ),
          for (final s
              in recommendations['suggested_sessions'] as List? ?? const [])
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.event_available_outlined),
              title: Text(
                '${_weekdays[((s as Map)['weekday'] as int) % 7]} à '
                '${s['start_hour']} h — ${s['duration_minutes']} min'
                '${s['subject'] != null ? ' (${s['subject']})' : ''}',
              ),
              subtitle: Text(s['reason'] as String? ?? ''),
            ),
          _bullets(ml.stringList(recommendations, 'learning_objectives')),
          _bullets(ml.stringList(recommendations, 'notes')),
        ],
        icon: Icons.lightbulb_outline,
      ),
    ];
  }

  String _period(String value) => switch (value) {
        'morning' => 'Matin',
        'afternoon' => 'Après-midi',
        'evening' => 'Soir',
        _ => 'Nuit',
      };

  Widget _aiSection() {
    final consent = _consent;
    if (consent == null || !consent.granted) {
      return _card(
        'Assistant IA',
        [
          const Text(
            'L’assistant IA utilise uniquement des données anonymisées '
            '(statistiques d’étude, sans nom ni e-mail). Il est facultatif et '
            'tu peux retirer ton accord à tout moment dans Confidentialité.',
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _busy ? null : _grantConsent,
            child: const Text('Autoriser l’assistant IA'),
          ),
        ],
        icon: Icons.auto_awesome_outlined,
      );
    }
    return _card(
      'Assistant IA',
      [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _generate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Générer des recommandations'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _analyze,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Analyser mon profil'),
            ),
            OutlinedButton.icon(
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Discuter'),
            ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
        ],
        if (_insight != null) ...[
          const SizedBox(height: 12),
          Text(
            _insight!.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(_insight!.body),
          _notice(_insight!.aiGenerated, _insight!.notice),
        ],
        const SizedBox(height: 8),
        for (final item in _recommendations) _recommendationTile(item),
      ],
      icon: Icons.auto_awesome_outlined,
    );
  }

  Widget _notice(bool aiGenerated, String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              aiGenerated ? Icons.smart_toy_outlined : Icons.rule,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );

  Widget _recommendationTile(AiRecommendation item) => Card(
        margin: const EdgeInsets.only(top: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Chip(
                    label: Text(item.aiGenerated ? 'IA' : 'Règles'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Text(item.description),
              if (item.reason != null) Text('Pourquoi : ${item.reason}'),
              if (item.suggestedAction != null)
                Text('Action : ${item.suggestedAction}'),
              Text('Priorité : ${_level(item.priority)}'),
              _notice(item.aiGenerated, item.notice),
              const SizedBox(height: 6),
              if (item.isPending)
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed:
                          _busy ? null : () => _decide(item, 'accepted'),
                      child: const Text('Accepter'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _modify(item),
                      child: const Text('Modifier'),
                    ),
                    TextButton(
                      onPressed:
                          _busy ? null : () => _decide(item, 'rejected'),
                      child: const Text('Refuser'),
                    ),
                  ],
                )
              else
                Text(
                  switch (item.status) {
                    'accepted' => 'Acceptée',
                    'modified' => 'Modifiée',
                    _ => 'Refusée',
                  },
                  style: Theme.of(context).textTheme.labelLarge,
                ),
            ],
          ),
        ),
      );
}

/// Ouvre l'assistant IA (chat) depuis n'importe quel écran, après avoir
/// vérifié le consentement de l'étudiant.
Future<void> openAiChat(BuildContext context, StudyMateApi api) async {
  try {
    final allowed = await ensureAiConsent(
      context,
      api,
      purpose: 'Pour te répondre, l’assistant reçoit ton message et un '
          'résumé anonyme de tes statistiques d’étude.',
    );
    if (!allowed || !context.mounted) return;
  } on StudyMateApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AiChatSheet(api: api),
  );
}

class AiChatSheet extends StatefulWidget {
  const AiChatSheet({super.key, required this.api});

  final StudyMateApi api;

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends State<AiChatSheet> {
  final _input = TextEditingController();
  final _messages = <({bool mine, String text})>[];
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add((mine: true, text: text));
      _sending = true;
      _input.clear();
    });
    String reply;
    try {
      reply = await widget.api.chatWithAi(text);
    } on StudyMateApiException catch (error) {
      reply = 'Assistant indisponible : ${error.message}';
    }
    if (!mounted) return;
    setState(() {
      _messages.add((mine: false, text: reply));
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const ListTile(
                title: Text('Assistant IA'),
                subtitle: Text(
                  'Réponses générées par une IA : elles peuvent contenir des '
                  'erreurs. Vérifie-les avant de t’y fier.',
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final message in _messages)
                      Align(
                        alignment: message.mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Card(
                          color: message.mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(message.text),
                          ),
                        ),
                      ),
                    if (_sending) const LinearProgressIndicator(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLength: 1000,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Pose ta question',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
