import 'package:app_settings/app_settings.dart';

enum PermissionSettingsTarget {
  app,
  notifications,
  calendar,
  photos,
}

class PermissionSettingsService {
  const PermissionSettingsService._();

  static Future<void> open(PermissionSettingsTarget target) async {
    switch (target) {
      case PermissionSettingsTarget.notifications:
        await AppSettings.openAppSettings(type: AppSettingsType.notification);
      case PermissionSettingsTarget.app:
      case PermissionSettingsTarget.calendar:
      case PermissionSettingsTarget.photos:
        await AppSettings.openAppSettings(type: AppSettingsType.settings);
    }
  }
}
