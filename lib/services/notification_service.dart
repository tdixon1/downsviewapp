import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'notification_navigation_service.dart';
import 'supabase_service.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.sabbathMorning = true,
    this.worshipReminder = true,
    this.midweekReminder = true,
    this.sermonPosted = true,
    this.eventReminders = true,
  });

  final bool sabbathMorning;
  final bool worshipReminder;
  final bool midweekReminder;
  final bool sermonPosted;
  final bool eventReminders;

  Map<String, dynamic> toJson() => {
        'sabbathMorning': sabbathMorning,
        'worshipReminder': worshipReminder,
        'midweekReminder': midweekReminder,
        'sermonPosted': sermonPosted,
        'eventReminders': eventReminders,
      };

  factory NotificationPreferences.fromJson(Map<String, dynamic>? json) {
    return NotificationPreferences(
      sabbathMorning: json?['sabbathMorning'] as bool? ?? true,
      worshipReminder: json?['worshipReminder'] as bool? ?? true,
      midweekReminder: json?['midweekReminder'] as bool? ?? true,
      sermonPosted: json?['sermonPosted'] as bool? ?? true,
      eventReminders: json?['eventReminders'] as bool? ?? true,
    );
  }
}

class NotificationService {
  NotificationService() : _localNotifications = FlutterLocalNotificationsPlugin();

  static const _pushChannel = AndroidNotificationChannel(
    'church-push',
    'Church Push Notifications',
    description: 'Notifications from Downsview SDA Church.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      'ic_stat_church_notification',
    );
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          NotificationNavigationService.instance.handleData(decoded);
        }
      },
    );

    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_pushChannel);

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(registerPushTokenSafely(tokenOverride: token));
    });
    FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showForegroundMessage(message));
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      NotificationNavigationService.instance.handleData(message.data);
    });
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      NotificationNavigationService.instance.handleData(initialMessage.data);
    }
  }

  Future<String?> registerPushToken({
    String? tokenOverride,
    bool forceRefresh = false,
  }) async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      throw Exception('Notification permission was not granted on this device.');
    }

    String? staleToken;
    if (forceRefresh && tokenOverride == null) {
      staleToken = await FirebaseMessaging.instance.getToken();
      await FirebaseMessaging.instance.deleteToken();
    }
    final token = tokenOverride ?? await FirebaseMessaging.instance.getToken();
    final user = supabase.auth.currentUser;
    if (user == null || token == null) {
      throw Exception(user == null
          ? 'Please sign in before registering this device.'
          : 'Firebase did not return a push token.');
    }

    if (forceRefresh) {
      await supabase.from('push_tokens').delete().eq('user_id', user.id);
    }

    final payload = {
      'user_id': user.id,
      'fcm_token': token,
      'platform': _platformLabel,
      'device_name': _deviceName,
      'last_seen_at': DateTime.now().toIso8601String(),
      'disabled_at': null,
    };

    try {
      await supabase.from('push_tokens').upsert(payload, onConflict: 'fcm_token');
      if (staleToken != null && staleToken != token) {
        await supabase
            .from('push_tokens')
            .update({'disabled_at': DateTime.now().toIso8601String()})
            .eq('fcm_token', staleToken);
      }
    } catch (error) {
      if (_looksLikeMissingFcmSchema(error)) {
        throw Exception(
          'Push token table needs an fcm_token column and matching unique constraint.',
        );
      }
      rethrow;
    }

    return token;
  }

  Future<String?> registerPushTokenSafely({String? tokenOverride}) async {
    try {
      return registerPushToken(tokenOverride: tokenOverride);
    } catch (_) {
      return null;
    }
  }

  Future<String?> registerSignedInDeviceSafely() async {
    try {
      await supabase.auth.refreshSession();
    } catch (_) {
      // The current cached session is still usable for registration attempts.
    }

    if (supabase.auth.currentUser == null) return null;
    return registerPushTokenSafely();
  }

  Future<String?> registerAuthorizedDeviceSafely() async {
    try {
      await supabase.auth.refreshSession();
    } catch (_) {
      // The current cached session is still usable for registration attempts.
    }

    if (!canSendPush(supabase.auth.currentUser)) return null;
    return registerPushTokenSafely();
  }

  Future<bool> scheduleChurchReminders(NotificationPreferences preferences) async {
    // Exact recurring notification scheduling depends on timezone initialization.
    // The UI can save preferences now; production scheduling is a follow-up step.
    return preferences.sabbathMorning ||
        preferences.worshipReminder ||
        preferences.midweekReminder;
  }

  Future<bool> scheduleEventReminder(String title, String dateLabel, [String? timeLabel]) async {
    final canNotify = await _ensureLocalNotificationPermission();
    if (!canNotify) return false;

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: [dateLabel, timeLabel].whereType<String>().join(' | '),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'event-reminders',
          'Event Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    return true;
  }

  Future<bool> _ensureLocalNotificationPermission() async {
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final enabled = await android.areNotificationsEnabled();
      if (enabled == true) return true;
      final granted = await android.requestNotificationsPermission();
      return granted == true;
    }

    final ios = _localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted == true;
    }

    return true;
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    final image = await _downloadNotificationImage(
      message.data['imageUrl'] as String? ??
          message.data['eventImageUrl'] as String? ??
          message.data['postImageUrl'] as String? ??
          notification?.android?.imageUrl ??
          notification?.apple?.imageUrl,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'church-push',
          'Church Push Notifications',
          channelDescription: 'Notifications from Downsview SDA Church.',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_church_notification',
          styleInformation: image?.androidStyle,
        ),
        iOS: DarwinNotificationDetails(
          attachments: image?.iosAttachment == null ? null : [image!.iosAttachment!],
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<_NotificationImage?> _downloadNotificationImage(String? url) async {
    if (url == null || url.isEmpty || !url.startsWith(RegExp(r'https?://'))) {
      return null;
    }

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300 || response.bodyBytes.isEmpty) {
        return null;
      }

      final androidStyle = BigPictureStyleInformation(
        ByteArrayAndroidBitmap(response.bodyBytes),
        largeIcon: ByteArrayAndroidBitmap(response.bodyBytes),
      );

      DarwinNotificationAttachment? iosAttachment;
      if (!kIsWeb && Platform.isIOS) {
        final extension = Uri.parse(url).path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
        final file = File(
          '${Directory.systemTemp.path}/downsview-notification-${DateTime.now().millisecondsSinceEpoch}.$extension',
        );
        await file.writeAsBytes(response.bodyBytes, flush: true);
        iosAttachment = DarwinNotificationAttachment(file.path);
      }

      return _NotificationImage(
        androidStyle: androidStyle,
        iosAttachment: iosAttachment,
      );
    } catch (_) {
      return null;
    }
  }
}

class _NotificationImage {
  const _NotificationImage({
    required this.androidStyle,
    this.iosAttachment,
  });

  final BigPictureStyleInformation androidStyle;
  final DarwinNotificationAttachment? iosAttachment;
}

bool _looksLikeMissingFcmSchema(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('fcm_token') ||
      message.contains('schema cache') ||
      message.contains('column');
}

String get _platformLabel {
  if (kIsWeb) return 'web';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'flutter';
}

String get _deviceName => kIsWeb ? 'Web browser' : 'Flutter $_platformLabel device';
