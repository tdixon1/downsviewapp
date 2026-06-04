class Hymn {
  const Hymn({
    required this.number,
    required this.title,
    required this.category,
    this.firstLine,
    this.tune,
    this.author,
    this.publicDomain = false,
    this.lyrics,
  });

  final int number;
  final String title;
  final String category;
  final String? firstLine;
  final String? tune;
  final String? author;
  final bool publicDomain;
  final String? lyrics;

  factory Hymn.fromJson(Map<String, dynamic> json) => Hymn(
        number: json['number'] as int,
        title: json['title'] as String,
        category: json['category'] as String? ?? 'Hymn',
        firstLine: json['firstLine'] as String?,
        tune: json['tune'] as String?,
        author: json['author'] as String?,
        publicDomain: json['publicDomain'] as bool? ?? false,
        lyrics: json['lyrics'] as String?,
      );
}
