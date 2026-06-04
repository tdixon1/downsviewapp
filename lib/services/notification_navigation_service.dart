import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/church_content.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

class NotificationNavigationTarget {
  const NotificationNavigationTarget._({
    required this.type,
    this.url,
    this.event,
  });

  final String type;
  final String? url;
  final ChurchEvent? event;

  factory NotificationNavigationTarget.fromData(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    if (action == 'open_post') {
      return NotificationNavigationTarget._(
        type: action!,
        url: data['url'] as String?,
      );
    }

    if (action == 'open_event') {
      return NotificationNavigationTarget._(
        type: action!,
        event: ChurchEvent(
          title: data['eventTitle'] as String? ?? data['title'] as String? ?? 'Church Event',
          dateLabel: data['eventDateLabel'] as String? ?? 'Upcoming',
          timeLabel: data['eventTimeLabel'] as String?,
          url: data['url'] as String?,
          details: data['eventDetails'] as String?,
          imageUrl: data['eventImageUrl'] as String?,
          isClosed: data['eventIsClosed'] == 'true' || data['eventIsClosed'] == true,
        ),
      );
    }

    return const NotificationNavigationTarget._(type: 'unknown');
  }
}

class NotificationNavigationService {
  NotificationNavigationService._();

  static final instance = NotificationNavigationService._();

  final _controller = StreamController<NotificationNavigationTarget>.broadcast();
  NotificationNavigationTarget? _pendingTarget;

  Stream<NotificationNavigationTarget> get stream => _controller.stream;

  void handleData(Map<String, dynamic> data) {
    final target = NotificationNavigationTarget.fromData(data);
    if (target.type == 'unknown') return;
    _pendingTarget = target;
    _controller.add(target);
  }

  NotificationNavigationTarget? takePendingTarget() {
    final target = _pendingTarget;
    _pendingTarget = null;
    return target;
  }
}

Future<void> openNotificationUrl(String? url) async {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
