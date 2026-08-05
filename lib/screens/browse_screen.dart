import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import 'reading_screen.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text('Browse'),
          bottom: const TabBar(tabs: [Tab(text: 'Surah'), Tab(text: 'Juz')]),
        ),
        body: const TabBarView(children: [_SurahListView(), _JuzListView()]),
      ),
    );
  }
}

class _SurahListView extends StatelessWidget {
  const _SurahListView();

  @override
  Widget build(BuildContext context) {
    final surahs = context.read<AppState>().quran.surahs;
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
            style: const TextStyle(fontFamily: 'QuranNaskh', fontSize: 18),
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
    final appState = context.read<AppState>();
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
                style: TextStyle(fontFamily: 'QuranNaskh', fontSize: 15, color: colorScheme.primary),
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
