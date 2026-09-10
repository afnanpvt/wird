import 'package:flutter/material.dart';

/// App credit, third-party attribution, and feedback contact - deliberately
/// its own screen rather than inline on Profile, the way most apps tuck
/// this away in Settings > About instead of surfacing it to everyone
/// scrolling their own profile.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Image.asset(
            Theme.of(context).brightness == Brightness.dark
                ? 'assets/images/logo_foreground_dark.png'
                : 'assets/images/logo_foreground.png',
            height: 44,
          ),
          const SizedBox(height: 10),
          Text('built by afnan', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          // Attribution for bundled third-party text/fonts/audio - the
          // IndoPak font's own licence asks for a courtesy credit
          // somewhere users can find it, which is here.
          Text(
            'Quran text: QuranWBW IndoPak and Tanzil Uthmani.\n'
            'Arabic type: Amiri, AlQuran IndoPak by QuranWBW.\n'
            'Recitation: everyayah.com.',
            style: TextStyle(fontSize: 12.5, height: 1.7, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          Text('feedback or issues', style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          SelectableText(
            'afnan.wird@gmail.com',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
