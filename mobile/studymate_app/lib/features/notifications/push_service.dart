import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/firebase_config.dart';
import '../../data/services/studymate_api.dart';

/// Top-level handler required by FCM for background/terminated messages.
/// Messages carrying a `notification` payload are displayed by the system.
@pragma('vm:entry-point')
Future<void> studyMateBackgroundMessageHandler(RemoteMessage message) async {
  final options = StudyMateFirebaseConfig.options;
  if (options != null && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }
}

typedef ForegroundMessageCallback = void Function(String title, String body);

/// Handles notification permission, FCM token registration with the backend
/// and foreground message delivery.
class PushService {
  PushService(this._api, {this.onForegroundMessage});

  final StudyMateApi _api;
  final ForegroundMessageCallback? onForegroundMessage;

  String? _token;
  String? _deviceId;
  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;

  bool get isRegistered => _deviceId != null;

  String get _platform => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        TargetPlatform.android => 'android',
        _ => 'web',
      };

  Future<AuthorizationStatus> permissionStatus() async =>
      (await FirebaseMessaging.instance.getNotificationSettings())
          .authorizationStatus;

  /// Asks the user for permission and registers this device when granted.
  Future<bool> enable() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) return false;
    await _register();
    return true;
  }

  /// Re-registers silently when permission was already granted.
  Future<void> syncIfPermitted() async {
    try {
      final status = await permissionStatus();
      if (status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional) {
        await _register();
      }
    } catch (_) {
      // Push is optional: never block the app.
    }
  }

  Future<void> disable() async {
    final deviceId = _deviceId;
    await _refreshSubscription?.cancel();
    await _messageSubscription?.cancel();
    _refreshSubscription = null;
    _messageSubscription = null;
    _deviceId = null;
    _token = null;
    try {
      if (deviceId != null) await _api.unregisterDevice(deviceId);
    } catch (_) {
      // The backend prunes invalid tokens on the next delivery.
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _register() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    _token = token;
    _deviceId = await _api.registerDevice(
      fcmToken: token,
      platform: _platform,
      deviceName: defaultTargetPlatform.name,
    );
    _refreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen((fresh) async {
      if (fresh == _token) return;
      _token = fresh;
      try {
        _deviceId = await _api.registerDevice(
          fcmToken: fresh,
          platform: _platform,
          deviceName: defaultTargetPlatform.name,
        );
      } catch (_) {}
    });
    _messageSubscription ??= FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      onForegroundMessage?.call(
        notification.title ?? 'StudyMate',
        notification.body ?? '',
      );
    });
  }
}
