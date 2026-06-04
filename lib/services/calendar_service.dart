import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/services.dart';

import '../models/church_content.dart';

class CalendarAddResult {
  const CalendarAddResult({
    required this.opened,
    required this.message,
  });

  final bool opened;
  final String message;
}

class CalendarService {
  Future<CalendarAddResult> addEventToCalendar(ChurchEvent churchEvent) async {
    final startDate = _parseEventDate(churchEvent);
    final event = Event(
      title: churchEvent.title,
      description: churchEvent.details,
      location: 'Downsview SDA Church',
      startDate: startDate,
      endDate: startDate.add(const Duration(hours: 1)),
    );
    try {
      final opened = await Add2Calendar.addEvent2Cal(event);
      return CalendarAddResult(
        opened: opened,
        message: opened
            ? '${churchEvent.title} is ready to add in your calendar app.'
            : 'No calendar app was found for adding this event. Install or enable Google Calendar, then try again.',
      );
    } on PlatformException catch (error) {
      return CalendarAddResult(
        opened: false,
        message: error.message ?? 'Could not open your calendar app.',
      );
    }
  }

  DateTime _parseEventDate(ChurchEvent event) {
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final now = DateTime.now();
    final dateMatch =
        RegExp(r'^([A-Za-z]{3})\s+(\d{1,2})$').firstMatch(event.dateLabel);
    final month = months[dateMatch?.group(1)] ?? now.month;
    final day = int.tryParse(dateMatch?.group(2) ?? '') ?? now.day;
    var date = DateTime(now.year, month, day, 9);

    final timeMatch =
        RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?', caseSensitive: false)
            .firstMatch(event.timeLabel ?? '');
    if (timeMatch != null) {
      var hour = int.parse(timeMatch.group(1)!);
      final minute = int.tryParse(timeMatch.group(2) ?? '') ?? 0;
      final meridian = timeMatch.group(3)?.toUpperCase();
      if (meridian == 'PM' && hour < 12) hour += 12;
      if (meridian == 'AM' && hour == 12) hour = 0;
      date = DateTime(now.year, month, day, hour, minute);
    }

    if (date.isBefore(now)) {
      date = DateTime(date.year + 1, date.month, date.day, date.hour, date.minute);
    }
    return date;
  }
}
