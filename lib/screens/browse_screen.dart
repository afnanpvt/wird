import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quran_script.dart';
import '../services/app_state.dart';
import '../widgets/quick_page_physics.dart';
import '../widgets/surah_list_view.dart';
import 'reading_screen.dart';

/// Lowercases and strips everything but letters/digits, so "Al-Baqara",
/// "al baqara" and "ALBAQARA" all compare equal - the transliterated names
/// in the data use hyphens and capitalization inconsistently enough that a
/// literal substring match would miss obvious hits.
String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

bool _matchesQuery(String query, {required int number, required List<String> names}) {
  if (query.isEmpty) return true;
  if (number.toString().startsWith(query.trim())) return true;
  final normalizedQuery = _normalize(query);
  return names.any((name) => _normalize(name).contains(normalizedQuery));
}

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('Browse'),
          bottom: const TabBar(tabs: [Tab(text: 'Surah'), Tab(text: 'Juz'), Tab(text: 'Saved')]),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by name or number',
                  prefixIcon: Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const QuickPageScrollPhysics(),
                children: [
                  SurahListView(query: _query),
                  _JuzListView(query: _query),
                  _SavedListView(query: _query),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No matches',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _JuzListView extends StatelessWidget {
  final String query;

  const _JuzListView({required this.query});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final allJuzs = appState.quran.juzs;
    final colorScheme = Theme.of(context).colorScheme;

    final juzs = allJuzs.where((j) => _matchesQuery(query, number: j.number, names: [j.name])).toList();

    if (juzs.isEmpty) return const _EmptySearchResult();

    return ListView.separated(
      itemCount: juzs.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final juz = juzs[index];
        final startSurah = appState.quran.surahByNumber(juz.startSurah);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: SizedBox(
            width: 32,
            child: Text('${juz.number}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          title: Text('Juz ${juz.number}', style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(juz.name, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 10),
                  Text(
                    juz.arabicName,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: appState.quranScript.fontFamily, fontSize: 15, height: 1.8, color: colorScheme.primary),
                  ),
                ],
              ),
              Text(
                'Starts in ${startSurah.englishName}, ayah ${juz.startAyah}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReadingScreen(
                initialSurahNumber: juz.startSurah,
                initialAyahNumber: juz.startAyah,
                updatesContinuePoint: false,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SavedListView extends StatelessWidget {
  final String query;

  const _SavedListView({required this.query});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final allFavorites = appState.favorites;
    final colorScheme = Theme.of(context).colorScheme;

    if (allFavorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, size: 40, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'No saved verses yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap the heart while reading a verse to save it here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final favorites = allFavorites.where((f) {
      final surah = appState.quran.surahByNumber(f.surahNumber);
      return _matchesQuery(query, number: surah.number, names: [surah.name, surah.englishName]);
    }).toList();

    if (favorites.isEmpty) return const _EmptySearchResult();

    return ListView.separated(
      itemCount: favorites.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        final surah = appState.quran.surahByNumber(favorite.surahNumber);
        final ayah = appState.quran.ayahsForSurah(favorite.surahNumber)[favorite.ayahNumber - 1];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          title: Text(
            '${surah.englishName} · ${favorite.ayahNumber}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              appState.useSimpleTranslation ? ayah.simpleEnglishText : ayah.englishText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          trailing: IconButton(
            tooltip: 'Remove from saved verses',
            icon: Icon(Icons.favorite, color: colorScheme.primary),
            onPressed: () => appState.toggleFavorite(favorite.surahNumber, favorite.ayahNumber),
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReadingScreen(
                initialSurahNumber: favorite.surahNumber,
                initialAyahNumber: favorite.ayahNumber,
                updatesContinuePoint: false,
              ),
            ),
          ),
        );
      },
    );
  }
}
