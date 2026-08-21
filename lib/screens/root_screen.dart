import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/playback_service.dart';
import '../widgets/coach_tour.dart';
import '../widgets/mini_player_bar.dart';
import 'bookmarks_screen.dart';
import 'browse_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Persistent bottom-tab shell around the app's four top-level destinations.
///
/// Replaces the earlier design where Browse, Bookmarks, and Settings were
/// only reachable by scrolling down Home and tapping a button, or a small
/// icon inside a card - on a short screen the Browse button in particular
/// could sit below the fold, so a first-run reader had to be told to scroll
/// before they could even see it. A bottom bar puts all four destinations on
/// screen, always, on every screen.
///
/// Each tab is a genuine [IndexedStack] entry, not something pushed onto the
/// Navigator - so switching tabs never rebuilds another tab's scroll
/// position or in-progress state, and none of them show a back arrow (there
/// is nothing to pop back to; they're siblings, not a stack).
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _selectedIndex = 0;

  final _continueReadingKey = GlobalKey();
  final _browseTabKey = GlobalKey();
  final _settingsTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Lets a finished Surah advance into the next one on its own, without
    // PlaybackService needing to know about QuranRepository or the reciter
    // setting itself - see AppState.playSurah.
    context.read<PlaybackService>().configureAutoAdvance(
      (nextSurahNumber) => context.read<AppState>().playSurah(context.read<PlaybackService>(), nextSurahNumber),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      if (appState.hasSeenCoachTour) return;
      appState.markCoachTourSeen();
      CoachTour.show(context, [
        CoachStep(
          targetKey: _continueReadingKey,
          title: 'Pick up where you left off',
          description: "This always points to your last read ayah, so you never lose your place.",
        ),
        CoachStep(
          targetKey: _browseTabKey,
          title: 'Browse any Surah or Juz',
          description: "Jump anywhere in the Quran whenever you want, without disturbing your progress.",
        ),
        CoachStep(
          targetKey: _settingsTabKey,
          title: 'Your settings',
          description: "Change your name, script, theme, or translation style here.",
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(continueReadingKey: _continueReadingKey),
          const BrowseScreen(),
          const BookmarksScreen(),
          const SettingsScreen(),
        ],
      ),
      // Explicit theming rather than the Material 3 defaults, to keep this
      // bar on the same monochrome-with-accent-for-active-state rule as the
      // rest of the app (see DESIGN.md) instead of picking up whatever
      // derived secondaryContainer tone falls out of the custom ColorScheme.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayerBar(),
          NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: colorScheme.surfaceContainerLow,
              indicatorColor: colorScheme.primary.withValues(alpha: 0.14),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color: states.contains(WidgetState.selected) ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  fontSize: 12,
                  fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
                  color: states.contains(WidgetState.selected) ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: colorScheme.outlineVariant, width: 1))),
              child: NavigationBar(
                elevation: 0,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                destinations: [
                  const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
                  NavigationDestination(
                    icon: KeyedSubtree(key: _browseTabKey, child: const Icon(Icons.explore_outlined)),
                    selectedIcon: const Icon(Icons.explore_rounded),
                    label: 'Browse',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.bookmark_outline_rounded),
                    selectedIcon: Icon(Icons.bookmark_rounded),
                    label: 'Bookmarks',
                  ),
                  NavigationDestination(
                    icon: KeyedSubtree(key: _settingsTabKey, child: const Icon(Icons.settings_outlined)),
                    selectedIcon: const Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
