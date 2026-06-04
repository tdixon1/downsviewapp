import 'dart:async';

import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/notification_navigation_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import 'appeals_screen.dart';
import 'home_screen.dart';
import 'info_screen.dart';
import 'profile_screen.dart';
import 'team_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.isGuest,
    required this.onSignInPress,
  });

  final bool isGuest;
  final VoidCallback onSignInPress;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  String? _autoRegisteredUserId;
  StreamSubscription<NotificationNavigationTarget>? _notificationSubscription;
  final _infoKey = GlobalKey<InfoScreenState>();
  late HomeScreen _homeScreen;
  late ProfileScreen _profileScreen;
  late InfoScreen _infoScreen;
  final _appealsScreen = const AppealsScreen();
  final _teamScreen = const TeamScreen();

  @override
  void initState() {
    super.initState();
    _homeScreen = HomeScreen(
      isGuest: widget.isGuest,
      onSignInPress: widget.onSignInPress,
    );
    _profileScreen = ProfileScreen(
      isGuest: widget.isGuest,
      onSignInPress: widget.onSignInPress,
    );
    _infoScreen = InfoScreen(key: _infoKey);
    _notificationSubscription = NotificationNavigationService.instance.stream.listen(_handleNotificationNavigation);
    final pendingTarget = NotificationNavigationService.instance.takePendingTarget();
    if (pendingTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleNotificationNavigation(pendingTarget));
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGuest != widget.isGuest) {
      _autoRegisteredUserId = null;
      _homeScreen = HomeScreen(
        isGuest: widget.isGuest,
        onSignInPress: widget.onSignInPress,
      );
      _profileScreen = ProfileScreen(
        isGuest: widget.isGuest,
        onSignInPress: widget.onSignInPress,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    _autoRegisterSignedInDevice(user?.id);
    final showTeamTab = hasAnyRole(user, const [
      'admin',
      'pastor',
      'staff',
      'interest_coordinator',
      'coordinator',
      'property_manager',
      'property',
      'social_media',
      'security',
      'prayer_team',
      'clerk',
    ]);

    final destinations = [
      _Destination(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        screen: _homeScreen,
      ),
      _Destination(
        label: 'Info',
        icon: Icons.newspaper_outlined,
        selectedIcon: Icons.newspaper,
        screen: _infoScreen,
      ),
      _Destination(
        label: 'Response',
        icon: Icons.chat_bubble_outline,
        selectedIcon: Icons.chat_bubble,
        screen: _appealsScreen,
      ),
      if (showTeamTab)
        _Destination(
          label: 'Team',
          icon: Icons.business_center_outlined,
          selectedIcon: Icons.business_center,
          screen: _teamScreen,
        ),
      _Destination(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        screen: _profileScreen,
      ),
    ];

    final safeIndex = _index.clamp(0, destinations.length - 1).toInt();

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: [for (final destination in destinations) destination.screen],
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E102A43),
                offset: Offset(0, 8),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _TabButton(
                    destination: destinations[i],
                    selected: i == safeIndex,
                    onTap: () => setState(() => _index = i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _autoRegisterSignedInDevice(String? userId) {
    if (widget.isGuest || userId == null || _autoRegisteredUserId == userId) return;
    _autoRegisteredUserId = userId;
    unawaited(NotificationService().registerSignedInDeviceSafely());
  }

  void _handleNotificationNavigation(NotificationNavigationTarget target) {
    if (!mounted) return;
    if (target.type == 'open_post') {
      unawaited(openNotificationUrl(target.url));
      return;
    }
    if (target.type == 'open_event' && target.event != null) {
      setState(() => _index = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _infoKey.currentState?.showEventFromNotification(target.event!);
      });
    }
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : const Color(0xFFA9B4C5);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? destination.selectedIcon : destination.icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}
