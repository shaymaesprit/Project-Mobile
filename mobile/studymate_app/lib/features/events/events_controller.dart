import 'package:flutter/foundation.dart';

import '../../data/local/events_local_db.dart';
import '../../data/models/event_models.dart';
import '../../data/services/studymate_api.dart';

/// État de la gestion Événements & Notifications (calendrier + centre de
/// notifications).
///
/// Stratégie « local d'abord » : on affiche les lignes SQLite, puis on appelle
/// l'API, on met SQLite à jour et on rafraîchit l'écran. Si l'API échoue, on
/// garde l'affichage local et on passe en mode hors ligne (bandeau).
class EventsController extends ChangeNotifier {
  EventsController(
    this._api, {
    String? Function()? userIdProvider,
    EventsLocalDb? localDb,
  })  : _userIdProvider = userIdProvider,
        _db = localDb ?? EventsLocalDb.instance;

  final StudyMateApi _api;
  final String? Function()? _userIdProvider;
  final EventsLocalDb _db;
  StudyMateApi get api => _api;

  /// Identifiant de l'étudiant connecté ; sans lui, aucune lecture/écriture
  /// locale n'est faite (isolation des données).
  String? get _uid {
    final uid = _userIdProvider?.call();
    return (uid == null || uid.isEmpty) ? null : uid;
  }

  bool _isOffline = false;
  DateTime? _lastSyncedAt;
  bool _eventsCached = false;
  bool _guardRun = false;

  /// Vrai quand le dernier appel API a échoué : les données affichées
  /// viennent de SQLite.
  bool get isOffline => _isOffline;

  /// Date de la dernière synchronisation réussie enregistrée en local.
  DateTime? get lastSyncedAt => _lastSyncedAt;

  List<CalendarItem> _items = const [];
  List<AppNotification> _notifications = const [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  List<CalendarItem> get items => List.unmodifiable(_items);
  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Purge de sécurité au premier accès : si la base contient des lignes d'un
  /// autre étudiant (déconnexion interrompue), elles sont supprimées.
  Future<void> _ensureGuard(String uid) async {
    if (_guardRun) return;
    _guardRun = true;
    try {
      await _db.purgeOtherUsers(uid);
    } catch (_) {
      // La base locale reste un confort : jamais bloquant.
    }
  }

  /// Charge le calendrier unifié sur [from, to) : SQLite d'abord, puis API.
  Future<void> loadRange(DateTime from, DateTime to) async {
    _errorMessage = null;
    final uid = _uid;

    // 1) Affichage immédiat des lignes locales.
    var hasLocal = false;
    if (uid != null) {
      try {
        await _ensureGuard(uid);
        final local = await _db.getCalendarItems(uid, from, to);
        _lastSyncedAt = await _db.lastSyncedAt(uid);
        if (local.isNotEmpty) {
          _items = local;
          hasLocal = true;
        }
      } catch (_) {
        // Lecture locale impossible : on continue avec l'API seule.
      }
    }
    _isLoading = true;
    _notify();

    // 2) API -> mise à jour de SQLite -> rafraîchissement de l'écran.
    try {
      final remote = await _api.getCalendar(from, to);
      _isOffline = false;
      _items = remote;
      if (uid != null) {
        try {
          await _db.replaceCalendarRange(uid, from, to, remote);
          _lastSyncedAt = await _db.lastSyncedAt(uid);
        } catch (_) {}
        _cacheEventsInBackground(uid);
      }
    } on StudyMateApiException catch (error) {
      // 3) Échec API : on garde l'affichage local.
      if (uid != null) {
        _isOffline = true;
        if (!hasLocal) {
          _items = const [];
          _errorMessage = error.message;
        }
      } else {
        _errorMessage = error.message;
      }
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Copie locale des événements complets (table `events`) pour pouvoir
  /// ouvrir une fiche hors ligne. Une fois par session, sans bloquer l'écran.
  void _cacheEventsInBackground(String uid) {
    if (_eventsCached) return;
    _eventsCached = true;
    _api.getEvents().then((events) => _db.upsertEvents(uid, events)).catchError(
      (Object _) {
        _eventsCached = false; // on réessaiera au prochain chargement
      },
    );
  }

  /// Fiche d'un événement : API puis cache ; hors ligne, lecture SQLite.
  Future<StudyEvent> getEvent(String id) async {
    final uid = _uid;
    try {
      final event = await _api.getEvent(id);
      if (uid != null) {
        try {
          await _db.upsertEvent(uid, event);
        } catch (_) {}
      }
      return event;
    } on StudyMateApiException {
      if (uid != null) {
        final cached = await _db.getEvent(uid, id);
        if (cached != null) {
          _isOffline = true;
          _notify();
          return cached;
        }
      }
      rethrow;
    }
  }

  /// À appeler après la création / modification d'un événement.
  Future<void> cacheEvent(StudyEvent event) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.upsertEvent(uid, event);
    } catch (_) {}
  }

  /// À appeler après la suppression d'un événement.
  Future<void> forgetEvent(String id) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.deleteEvent(uid, id);
      _items = _items.where((i) => !(i.kind == 'event' && i.id == id)).toList();
      _notify();
    } catch (_) {}
  }

  /// Recherche locale (SQL LIKE) : marche sans réseau.
  Future<List<CalendarItem>> search(String query) async {
    final uid = _uid;
    if (uid == null || query.trim().isEmpty) return const [];
    return _db.searchCalendarItems(uid, query);
  }

  /// Nombre d'éléments à venir par catégorie (GROUP BY SQL).
  Future<Map<String, int>> upcomingStats() async {
    final uid = _uid;
    if (uid == null) return const {};
    return _db.countByCategory(uid, DateTime.now());
  }

  List<CalendarItem> itemsOn(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    bool touchesDay(CalendarItem item) {
      final itemStart = item.startsAt;
      final itemEnd = item.endsAt ?? item.startsAt;
      final isPoint = !itemEnd.isAfter(itemStart);
      return itemStart.isBefore(end) &&
          (isPoint ? !itemStart.isBefore(start) : itemEnd.isAfter(start));
    }

    return _items.where(touchesDay).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  Future<void> refreshUnread() async {
    final uid = _uid;
    try {
      final count = await _api.getUnreadNotificationCount();
      if (count != _unreadCount) {
        _unreadCount = count;
        _notify();
      }
    } on StudyMateApiException {
      // Hors ligne : on compte les non lues en local.
      if (uid != null) {
        try {
          final local = await _db.unreadCount(uid);
          if (local != _unreadCount) {
            _unreadCount = local;
            _notify();
          }
        } catch (_) {}
      }
    }
  }

  Future<void> loadNotifications({bool unreadOnly = false, String? type}) async {
    _errorMessage = null;
    final uid = _uid;

    // 1) Lignes locales d'abord.
    var hasLocal = false;
    if (uid != null) {
      try {
        final local = await _db.getNotifications(
          uid,
          unreadOnly: unreadOnly,
          type: type,
        );
        if (local.isNotEmpty) {
          _notifications = local;
          hasLocal = true;
        }
        _lastSyncedAt = await _db.lastSyncedAt(uid);
      } catch (_) {}
    }
    _isLoading = true;
    _notify();

    // 2) API puis SQLite.
    try {
      final remote =
          await _api.getNotifications(unreadOnly: unreadOnly, type: type);
      _isOffline = false;
      _notifications = remote;
      if (uid != null) {
        try {
          await _db.upsertNotifications(
            uid,
            remote,
            replaceAll: !unreadOnly && type == null,
          );
          _lastSyncedAt = await _db.lastSyncedAt(uid);
        } catch (_) {}
      }
      await refreshUnread();
    } on StudyMateApiException catch (error) {
      if (uid != null) {
        _isOffline = true;
        if (!hasLocal) {
          _notifications = const [];
          _errorMessage = error.message;
        }
        await refreshUnread();
      } else {
        _errorMessage = error.message;
      }
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await _api.markNotificationRead(notification.id);
      final uid = _uid;
      if (uid != null) {
        await _db.markNotificationRead(uid, notification.id);
      }
      _notifications = [
        for (final item in _notifications)
          item.id == notification.id
              ? item.copyWith(readAt: DateTime.now())
              : item,
      ];
      if (_unreadCount > 0) _unreadCount -= 1;
      _notify();
    } on StudyMateApiException catch (error) {
      _errorMessage = error.message;
      _notify();
    }
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      final uid = _uid;
      if (uid != null) await _db.markAllNotificationsRead(uid);
      final now = DateTime.now();
      _notifications = [
        for (final item in _notifications)
          item.isRead ? item : item.copyWith(readAt: now),
      ];
      _unreadCount = 0;
      _notify();
    } on StudyMateApiException catch (error) {
      _errorMessage = error.message;
      _notify();
    }
  }

  Future<void> deleteNotification(AppNotification notification) async {
    try {
      await _api.deleteNotification(notification.id);
      final uid = _uid;
      if (uid != null) await _db.deleteNotification(uid, notification.id);
      _notifications =
          _notifications.where((item) => item.id != notification.id).toList();
      if (!notification.isRead && _unreadCount > 0) _unreadCount -= 1;
      _notify();
    } on StudyMateApiException catch (error) {
      _errorMessage = error.message;
      _notify();
    }
  }
}
