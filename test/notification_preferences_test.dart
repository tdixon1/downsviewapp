import 'package:downsview_sda/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification preferences default to enabled', () {
    final preferences = NotificationPreferences.fromJson(null);

    expect(preferences.sabbathMorning, isTrue);
    expect(preferences.worshipReminder, isTrue);
    expect(preferences.midweekReminder, isTrue);
    expect(preferences.sermonPosted, isTrue);
    expect(preferences.eventReminders, isTrue);
  });
}
