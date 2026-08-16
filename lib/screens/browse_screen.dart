import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quran_script.dart';
import '../services/app_state.dart';
import 'reading_screen.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('Browse'),
          bottom: const TabBar(tabs: [Tab(text: 'Surah'), Tab(text: 'Juz'), Tab(text: 'Saved')]),
        ),
        body: const TabBarView(children: [_SurahListView(), _JuzListView(), _SavedListView()]),
      ),
    );
  }
}

class _SurahListView extends StatelessWidget {
  const _SurahListView();

  @override
  Widget build(BuildContext context) {
    final surahs = context.read<AppState>().quran.surahs;
    final fontFamily = context.watch<AppState>().quranScript.fontFamily;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      itemCount: surahs.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final surah = surahs[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: SizedBox(
            width: 32,
            child: Text('${surah.number}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          title: Text(surah.englishName, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('${surah.name} · ${surah.ayahCount} ayahs'),
          trailing: Text(
            surah.arabicName,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: fontFamily, fontSize: 18, height: 1.8),
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReadingScreen(
                initialSurahNumber: surah.number,
                initialAyahNumber: 1,
                updatesContinuePoint: false,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JuzListView extends StatelessWidget {
  const _JuzListView();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final juzs = appState.quran.juzs;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      itemCount: juzs.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final juz = juzs[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: SizedBox(
            width: 32,
            child: Text('${juz.number}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          title: Text('Juz ${juz.number}', style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Row(
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
  const _SavedListView();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final favorites = appState.favorites;
    final colorScheme = Theme.of(context).colorScheme;

    if (favorites.isEmpty) {
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
