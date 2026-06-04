import 'package:flutter/material.dart';

import '../models/hymn.dart';
import '../services/hymnal_service.dart';
import '../services/url_service.dart';
import '../theme.dart';

class HymnalScreen extends StatefulWidget {
  const HymnalScreen({super.key});

  @override
  State<HymnalScreen> createState() => _HymnalScreenState();
}

class _HymnalScreenState extends State<HymnalScreen> {
  final _service = HymnalService();
  final _search = TextEditingController();

  List<Hymn> _hymns = const [];
  Set<int> _favorites = {};
  String _category = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hymns = await _service.loadHymns();
    if (!mounted) return;
    setState(() {
      _hymns = hymns;
      _loading = false;
    });
  }

  List<String> get _categories {
    final categories = _hymns.map((hymn) => hymn.category).toSet().toList()..sort();
    return ['All', 'Favorites', ...categories];
  }

  List<Hymn> get _filteredHymns {
    final query = _search.text.trim().toLowerCase();
    return _hymns.where((hymn) {
      final matchesCategory = _category == 'All' ||
          (_category == 'Favorites' && _favorites.contains(hymn.number)) ||
          hymn.category == _category;
      final matchesSearch = query.isEmpty ||
          hymn.number.toString() == query ||
          hymn.title.toLowerCase().contains(query) ||
          (hymn.firstLine?.toLowerCase().contains(query) ?? false) ||
          (hymn.tune?.toLowerCase().contains(query) ?? false);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _toggleFavorite(Hymn hymn) {
    setState(() {
      _favorites = {..._favorites};
      if (!_favorites.remove(hymn.number)) {
        _favorites.add(hymn.number);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hymns = _filteredHymns;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 128),
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.text,
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset('assets/downsview-logo-black.png', width: 190, alignment: Alignment.centerLeft),
              ],
            ),
            const SizedBox(height: 16),
            const _HymnalHero(),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by number, title, first line, or tune',
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _search.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final selected = category == _category;
                  return ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = category),
                    selectedColor: AppColors.navy,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                    side: const BorderSide(color: AppColors.border),
                    backgroundColor: Colors.white,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const _AdventHymnalsPanel(),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (hymns.isEmpty)
              const _EmptyHymns()
            else
              for (final hymn in hymns)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HymnCard(
                    hymn: hymn,
                    isFavorite: _favorites.contains(hymn.number),
                    onTap: () => openUrl(context, _adventHymnalsUrl(hymn)),
                    onFavorite: () => _toggleFavorite(hymn),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _AdventHymnalsPanel extends StatelessWidget {
  const _AdventHymnalsPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.public, color: AppColors.blue, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Advent Hymnals source', style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900)),
                SizedBox(height: 3),
                Text('Open the public SDA Hymnal collection online.', style: TextStyle(color: AppColors.slate, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => openUrl(context, 'https://adventhymnals.github.io/seventh-day-adventist-hymnal'),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.open_in_new, size: 15),
            label: const Text('Browse'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.blue,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _HymnalHero extends StatelessWidget {
  const _HymnalHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadii.hero),
        boxShadow: AppShadows.panel,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.music_note, color: AppColors.gold, size: 28),
          SizedBox(height: 16),
          Text(
            'Seventh-day Adventist Hymnal',
            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.08),
          ),
          SizedBox(height: 10),
          Text(
            'Find hymns by number, title, first line, category, or tune for worship and Sabbath School.',
            style: TextStyle(color: Color(0xFFD8E2EF), fontSize: 15, fontWeight: FontWeight.w700, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _HymnCard extends StatelessWidget {
  const _HymnCard({
    required this.hymn,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  final Hymn hymn;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  hymn.number.toString(),
                  style: const TextStyle(color: AppColors.blue, fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hymn.title, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      hymn.firstLine ?? hymn.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.slate, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(hymn.category, style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavorite,
                icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                color: isFavorite ? AppColors.gold : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _adventHymnalsUrl(Hymn hymn) {
  final number = hymn.number;
  final hundredStart = ((number - 1) ~/ 100) * 100 + 1;
  final hundredEnd = number <= 600 ? hundredStart + 99 : 695;
  final tenStart = ((number - 1) ~/ 10) * 10 + 1;
  final tenEnd = number <= 690 ? tenStart + 9 : 695;
  final titleSlug = hymn.title
      .replaceAll(RegExp(r"['!.?,;:]"), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'https://adventhymnals.github.io/v3/seventh-day-adventist-hymnal/'
      '${_pad(hundredStart)}-${_pad(hundredEnd)}/${_pad(tenStart)}-${_pad(tenEnd)}/$titleSlug';
}

String _pad(int value) => value.toString().padLeft(3, '0');

class _EmptyHymns extends StatelessWidget {
  const _EmptyHymns();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off, color: AppColors.muted, size: 34),
          SizedBox(height: 8),
          Text('No hymns found', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text('Try another hymn number, title, first line, or category.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.slate, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
