import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../services/studymate_api.dart';
import 'offline_outbox.dart';

/// Une création confirmée par le serveur : l'élément local [localId] porte
/// désormais l'identifiant du serveur, et [json] est sa version officielle.
typedef CreatedHandler = Future<void> Function(
  String entity,
  String localId,
  Map<String, dynamic> json,
);

/// Une opération refusée définitivement par le serveur (validation, conflit…).
typedef RejectedHandler = Future<void> Function(
  OutboxEntry entry,
  String message,
);

/// Rejoue la file d'attente hors ligne vers l'API.
///
/// Déclencheurs : retour du réseau (connectivity_plus), retour de l'app au
/// premier plan, nouvelle opération enregistrée, et réessai automatique avec
/// délai croissant (15 s → 5 min) tant qu'il reste des opérations.
///
/// Règles :
/// * ordre d'enregistrement strict (FIFO) ;
/// * erreur réseau / 5xx → on s'arrête et on réessaiera (rien n'est perdu) ;
/// * 404 sur modification/suppression → l'élément n'existe plus : ignoré ;
/// * autre refus (400/409/422…) → l'opération est retirée et signalée.
class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  SyncService({
    required StudyMateApi api,
    required String? Function() userIdProvider,
    OfflineOutbox? outbox,
    Stream<List<ConnectivityResult>>? connectivity,
  })  : _api = api,
        _uid = userIdProvider,
        _outbox = outbox ?? OfflineOutbox.instance {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub =
        (connectivity ?? Connectivity().onConnectivityChanged).listen((results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (connected && pendingCount > 0) {
        _backoff = _minBackoff;
        unawaited(flush());
      } else if (!connected) {
        _setOnline(false);
      }
    });
  }

  static const _minBackoff = Duration(seconds: 15);
  static const _maxBackoff = Duration(minutes: 5);

  final StudyMateApi _api;
  final String? Function() _uid;
  final OfflineOutbox _outbox;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  final _createdHandlers = <CreatedHandler>[];
  final _rejectedHandlers = <RejectedHandler>[];

  int _pendingCount = 0;
  bool _isSyncing = false;
  bool _isOnline = true;
  DateTime? _lastSyncedAt;
  String? _lastRejection;
  Timer? _retryTimer;
  Duration _backoff = _minBackoff;
  bool _disposed = false;

  int get pendingCount => _pendingCount;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Dernier refus du serveur (affiché une fois puis effacé).
  String? takeLastRejection() {
    final message = _lastRejection;
    _lastRejection = null;
    return message;
  }

  OfflineOutbox get outbox => _outbox;

  void onCreated(CreatedHandler handler) => _createdHandlers.add(handler);
  void onRejected(RejectedHandler handler) => _rejectedHandlers.add(handler);

  /// Enregistre une opération puis tente immédiatement de l'envoyer.
  Future<void> enqueue({
    required String entity,
    required OutboxOp op,
    required String entityId,
    Map<String, dynamic> payload = const {},
  }) async {
    final uid = _uid();
    if (uid == null) return;
    await _outbox.enqueue(
      userId: uid,
      entity: entity,
      op: op,
      entityId: entityId,
      payload: payload,
    );
    await refreshCount();
    unawaited(flush());
  }

  Future<void> refreshCount() async {
    final uid = _uid();
    _pendingCount = uid == null ? 0 : await _outbox.count(uid);
    _notify();
  }

  Future<bool>? _running;

  /// Envoie toutes les opérations en attente. Renvoie `true` si la file est vide.
  ///
  /// Si un envoi est déjà en cours, on attend sa fin puis on refait un passage
  /// (pour inclure ce qui a été ajouté entre-temps) : l'appelant obtient
  /// toujours un résultat à jour, et deux envois ne tournent jamais en même
  /// temps.
  Future<bool> flush() async {
    while (_running != null) {
      await _running;
    }
    final run = _flushOnce();
    _running = run;
    try {
      return await run;
    } finally {
      if (identical(_running, run)) _running = null;
    }
  }

  Future<bool> _flushOnce() async {
    final uid = _uid();
    if (uid == null) return true;
    _isSyncing = true;
    _retryTimer?.cancel();
    _notify();
    var stoppedOnNetwork = false;
    try {
      await _outbox.purgeOtherUsers(uid);
      while (true) {
        final queue = await _outbox.pending(uid);
        if (queue.isEmpty) break;
        final entry = queue.first;
        try {
          final serverId = await _send(uid, entry);
          if (entry.op == OutboxOp.create && serverId != null) {
            await _outbox.completeCreate(entry.id, entry.payload, serverId);
          } else {
            await _outbox.remove(entry.id);
          }
          _setOnline(true);
        } on StudyMateApiException catch (error) {
          final status = error.statusCode;
          if (error.isNetworkError || status == null || status >= 500 || status == 401) {
            await _outbox.markFailed(entry.id, error.message);
            stoppedOnNetwork = true;
            if (error.isNetworkError) _setOnline(false);
            break;
          }
          await _outbox.remove(entry.id);
          if (status == 404 && entry.op != OutboxOp.create) continue;
          _lastRejection = _describeRejection(entry, error.message);
          for (final handler in _rejectedHandlers) {
            await handler(entry, error.message);
          }
        }
      }
      if (!stoppedOnNetwork) {
        _lastSyncedAt = DateTime.now();
        _backoff = _minBackoff;
      }
    } finally {
      _isSyncing = false;
      await refreshCount();
      if (_pendingCount > 0) _scheduleRetry();
    }
    return _pendingCount == 0;
  }

  /// Envoie une opération ; pour une création, renvoie l'identifiant serveur.
  Future<String?> _send(String uid, OutboxEntry entry) async {
    final route = _routes[entry.entity];
    if (route == null) return null; // entité inconnue : ignorée
    switch (entry.op) {
      case OutboxOp.create:
        final json = await _api.syncRequest(
          'POST',
          '${route.collection}${route.query}',
          data: entry.payload,
        );
        final serverId = json?['id'] as String?;
        if (json != null && serverId != null) {
          await _outbox.remapId(uid, entry.entityId, serverId);
          for (final handler in _createdHandlers) {
            await handler(entry.entity, entry.entityId, json);
          }
        }
        return serverId;
      case OutboxOp.update:
        await _api.syncRequest(
          route.updateMethod,
          route.item(entry.entityId),
          data: entry.payload,
        );
      case OutboxOp.delete:
        await _api.syncRequest('DELETE', route.itemPath(entry.entityId));
    }
    return null;
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_backoff, () => unawaited(flush()));
    final next = _backoff * 2;
    _backoff = next > _maxBackoff ? _maxBackoff : next;
  }

  void _setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    _notify();
  }

  static String _describeRejection(OutboxEntry entry, String message) {
    final what = switch (entry.entity) {
      'course' => 'le cours',
      'task' => 'la tâche',
      'note' => 'la note',
      'event' => 'l’événement',
      _ => 'l’élément',
    };
    final verb = switch (entry.op) {
      OutboxOp.create => 'La création de',
      OutboxOp.update => 'La modification de',
      OutboxOp.delete => 'La suppression de',
    };
    return '$verb $what faite hors ligne a été refusée : $message';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingCount > 0) {
      _backoff = _minBackoff;
      unawaited(flush());
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _connectivitySub.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _Route {
  const _Route(this.collection, {this.updateMethod = 'PUT', this.query = ''});

  final String collection;
  final String updateMethod;

  /// Suffixe ajouté aux créations / modifications (ex. `?force=true`).
  final String query;

  String itemPath(String id) => '$collection/$id';
  String item(String id) => '${itemPath(id)}$query';
}

/// Correspondance entité → routes de l'API.
const _routes = {
  'course': _Route('/courses'),
  'task': _Route('/tasks', updateMethod: 'PATCH'),
  'note': _Route('/notes'),
  // Les conflits d'horaire ont déjà été signalés à l'étudiant sur le
  // téléphone : on force l'enregistrement, comme le fait le formulaire.
  'event': _Route('/events', query: '?force=true'),
};
