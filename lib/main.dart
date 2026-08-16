import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/app_state.dart';
import 'services/hive_service.dart';
import 'widgets/welcome_dialog.dart';

final routeObserver = RouteObserver<PageRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const WirdApp(),
    ),
  );
}

class WirdColors {
  static const clayLight = Color(0xFFA8562E);
  static const clayDark = Color(0xFFFF7A45);

  static const backgroundLight = Color(0xFFFAF7F2);
  static const surfaceLight = Color(0xFFF3EEE6);
  static const inkLight = Color(0xFF2B2622);
  static const mutedLight = Color(0xFF6B6259);
  static const dividerLight = Color(0xFFE3DCD0);

  static const backgroundDark = Color(0xFF0A0908);
  static const surfaceDark = Color(0xFF171512);
  static const inkDark = Color(0xFFF5F1EA);
  static const mutedDark = Color(0xFF8F857A);
  static const dividerDark = Color(0xFF2A2621);
}

class WirdApp extends StatelessWidget {
  const WirdApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appThemeMode = context.watch<AppState>().themeMode;
    final themeMode = switch (appThemeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp(
      title: 'wird.',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      navigatorObservers: [routeObserver],
      home: const _Bootstrap(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final ink = isLight ? WirdColors.inkLight : WirdColors.inkDark;
    final background = isLight ? WirdColors.backgroundLight : WirdColors.backgroundDark;
    final surface = isLight ? WirdColors.surfaceLight : WirdColors.surfaceDark;
    final muted = isLight ? WirdColors.mutedLight : WirdColors.mutedDark;
    final clay = isLight ? WirdColors.clayLight : WirdColors.clayDark;
    final divider = isLight ? WirdColors.dividerLight : WirdColors.dividerDark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: clay,
      onPrimary: isLight ? Colors.white : WirdColors.inkDark,
      secondary: clay,
      onSecondary: isLight ? Colors.white : WirdColors.inkDark,
      surface: background,
      onSurface: ink,
      surfaceContainerLowest: isLight ? Colors.white : const Color(0xFF15130F),
      surfaceContainerLow: surface,
      surfaceContainerHighest: surface,
      onSurfaceVariant: muted,
      outline: divider,
      outlineVariant: divider,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      dividerColor: divider,
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .black
          .apply(fontFamily: 'Inter', bodyColor: ink, displayColor: ink),
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _welcomeChecked = false;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().init();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final Widget child;
    final Key key;

    if (!appState.isLoaded) {
      child = const _LoadingScreen();
      key = const ValueKey('loading');
    } else if (!appState.hasCompletedOnboarding) {
      child = const OnboardingScreen();
      key = const ValueKey('onboarding');
    } else {
      if (!_welcomeChecked) {
        _welcomeChecked = true;
        final kind = appState.checkWelcomeModal();
        if (kind == 'back') {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await showWelcomeDialog(context, isFirstLaunch: false);
            await appState.markWelcomeModalShown();
          });
        } else if (kind == 'first') {
          appState.markWelcomeModalShown();
        }
      }
      child = const HomeScreen();
      key = const ValueKey('home');
    }

    // Cross-fades from the branded loading screen into the real app once
    // AppState finishes loading, instead of an abrupt cut.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(key: key, child: child),
    );
  }
}

/// Shown while [AppState.init] loads the Quran text and reading history off
/// disk - just the wordmark, matching the native Android launch screen
/// (see android/app/src/main/res/drawable{,-night}/launch_background.xml)
/// so there's no visible handoff between the OS splash and this screen, and
/// no spinner competing with a moment that's meant to read as a brand beat,
/// not a wait.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? 'assets/images/logo_foreground_dark.png'
              : 'assets/images/logo_foreground.png',
          height: 120,
        ),
      ),
    );
  }
}
