import 'package:flutter/foundation.dart';

import '../../data/models/event_models.dart';
import '../../data/services/studymate_api.dart';

/// État de la gestion Événements & Notifications (calendrier + centre de
/// notifications). Les données restent sur le backend ; ce contrôleur ne
/// garde que ce qui est affiché.
class EventsController extends ChangeNotifier {
  EventsController(this._api);

  final StudyMateApi _api;
  StudyMateApi get api => _api;

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

  /// Charge le calendrier unifié sur [from, to).
  Future<void> loadRange(DateTime from, DateTime to) async {
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      _items = await _api.getCalendar(from, to);
    } on StudyMateApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      _notify();
    }
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
    try {
      final count = await _api.getUnreadNotificationCount();
      if (count != _unreadCount) {
        _unreadCount = count;
        _notify();
      }
    } on StudyMateApiException {
      // Silencieux : la pastille n'est qu'un confort.
    }
  }

  Future<void> loadNotifications({bool unreadOnly = false, String? type}) async {
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      _notifications =
          await _api.getNotifications(unreadOnly: unreadOnly, type: type);
      await refreshUnread();
    } on StudyMateApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await _api.markNotificationRead(notification.id);
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
