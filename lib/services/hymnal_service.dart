import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/hymn.dart';

class HymnalService {
  Future<List<Hymn>> loadHymns() async {
    try {
      final raw = await rootBundle.loadString('assets/sda_hymnal.json');
      final json = jsonDecode(raw) as List<dynamic>;
      return json.map((item) => Hymn.fromJson(item as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.number.compareTo(b.number));
    } catch (_) {
      return _starterHymns;
    }
  }
}

const _starterHymns = [
  Hymn(number: 1, title: 'Praise to the Lord', category: 'Praise and Adoration', firstLine: 'Praise to the Lord, the Almighty', tune: 'Lobe den Herren', publicDomain: true),
  Hymn(number: 2, title: 'All Creatures of Our God and King', category: 'Praise and Adoration', firstLine: 'All creatures of our God and King', publicDomain: true),
  Hymn(number: 12, title: 'Joyful, Joyful, We Adore Thee', category: 'Praise and Adoration', firstLine: 'Joyful, joyful, we adore Thee', tune: 'Hymn to Joy', publicDomain: true),
  Hymn(number: 15, title: 'My Maker and My King', category: 'Praise and Adoration', firstLine: 'My Maker and my King', publicDomain: true),
  Hymn(number: 73, title: 'Holy, Holy, Holy', category: 'Trinity', firstLine: 'Holy, holy, holy! Lord God Almighty!', tune: 'Nicaea', publicDomain: true),
  Hymn(number: 100, title: 'Great Is Thy Faithfulness', category: 'God the Father', firstLine: 'Great is Thy faithfulness', publicDomain: false),
  Hymn(number: 108, title: 'Amazing Grace', category: 'God the Father', firstLine: 'Amazing grace! How sweet the sound', publicDomain: true),
  Hymn(number: 159, title: 'The Old Rugged Cross', category: 'Jesus Christ', firstLine: 'On a hill far away stood an old rugged cross', publicDomain: true),
  Hymn(number: 214, title: 'We Have This Hope', category: 'Second Advent', firstLine: 'We have this hope that burns within our hearts', publicDomain: false),
  Hymn(number: 251, title: 'He Lives', category: 'Jesus Christ', firstLine: 'I serve a risen Savior', publicDomain: false),
  Hymn(number: 286, title: 'Wonderful Words of Life', category: 'The Holy Scriptures', firstLine: 'Sing them over again to me', publicDomain: true),
  Hymn(number: 294, title: 'Power in the Blood', category: 'Salvation', firstLine: 'Would you be free from your burden of sin?', publicDomain: true),
  Hymn(number: 309, title: 'I Surrender All', category: 'Consecration', firstLine: 'All to Jesus I surrender', publicDomain: true),
  Hymn(number: 330, title: 'Take My Life and Let It Be', category: 'Consecration', firstLine: 'Take my life and let it be', publicDomain: true),
  Hymn(number: 341, title: 'To God Be the Glory', category: 'Praise and Adoration', firstLine: 'To God be the glory, great things He hath done', publicDomain: true),
  Hymn(number: 422, title: 'Marching to Zion', category: 'Christian Church', firstLine: 'Come, we that love the Lord', publicDomain: true),
  Hymn(number: 469, title: 'Leaning on the Everlasting Arms', category: 'Christian Life', firstLine: 'What a fellowship, what a joy divine', publicDomain: true),
  Hymn(number: 499, title: 'What a Friend We Have in Jesus', category: 'Prayer', firstLine: 'What a friend we have in Jesus', publicDomain: true),
  Hymn(number: 528, title: 'A Shelter in the Time of Storm', category: 'Comfort and Assurance', firstLine: 'The Lord is our Rock, in Him we hide', publicDomain: true),
  Hymn(number: 590, title: 'Trust and Obey', category: 'Christian Life', firstLine: 'When we walk with the Lord', publicDomain: true),
  Hymn(number: 604, title: 'We Know Not the Hour', category: 'Second Advent', firstLine: 'We know not the hour of the Master appearing', publicDomain: true),
  Hymn(number: 618, title: 'Stand Up! Stand Up for Jesus!', category: 'Conflict and Courage', firstLine: 'Stand up! stand up for Jesus!', publicDomain: true),
  Hymn(number: 625, title: 'Higher Ground', category: 'Christian Life', firstLine: 'I am pressing on the upward way', publicDomain: true),
  Hymn(number: 633, title: 'When We All Get to Heaven', category: 'Eternal Life', firstLine: 'Sing the wondrous love of Jesus', publicDomain: true),
];
