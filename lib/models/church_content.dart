class WpPost {
  const WpPost({
    required this.id,
    required this.date,
    required this.title,
    required this.excerpt,
    required this.content,
    this.link,
    this.imageUrl,
  });

  final int id;
  final DateTime date;
  final String title;
  final String excerpt;
  final String content;
  final String? link;
  final String? imageUrl;
}

class ChurchSermon {
  const ChurchSermon({
    required this.title,
    this.speaker,
    this.date,
    this.excerpt,
    this.url,
    this.imageUrl,
  });

  final String title;
  final String? speaker;
  final DateTime? date;
  final String? excerpt;
  final String? url;
  final String? imageUrl;

  bool get isUpcoming {
    if (date == null) return false;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final sermonDate = DateTime(date!.year, date!.month, date!.day);
    return !sermonDate.isBefore(todayStart);
  }
}

class ChurchBulletin {
  const ChurchBulletin({
    required this.title,
    required this.url,
    this.pdfUrl,
  });

  final String title;
  final String url;
  final String? pdfUrl;
}

class ChurchEvent {
  const ChurchEvent({
    required this.title,
    required this.dateLabel,
    this.timeLabel,
    this.url,
    this.details,
    this.imageUrl,
    this.isClosed = false,
  });

  final String title;
  final String dateLabel;
  final String? timeLabel;
  final String? url;
  final String? details;
  final String? imageUrl;
  final bool isClosed;
}

class SabbathLesson {
  const SabbathLesson({
    required this.ageGroup,
    required this.title,
    required this.summary,
    required this.url,
    required this.color,
    required this.accentColor,
    this.dateLabel,
    this.imageUrl,
  });

  final String ageGroup;
  final String title;
  final String summary;
  final String url;
  final String color;
  final String accentColor;
  final String? dateLabel;
  final String? imageUrl;
}
