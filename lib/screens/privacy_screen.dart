import 'package:flutter/material.dart';

/// The full privacy policy, in-app so it never depends on an external site
/// being reachable (or its address being known ahead of time). Reached from
/// About and from the backup sign-in screen. Keep this in sync with the
/// same policy published on the marketing site.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _lastUpdated = 'September 23, 2026';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final heading = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colorScheme.onSurface);
    final body = TextStyle(fontSize: 13.5, height: 1.5, color: colorScheme.onSurfaceVariant);
    Widget section(String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: heading),
              const SizedBox(height: 6),
              Text(text, style: body),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Privacy policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Last updated: $_lastUpdated', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            section(
              'Local by default',
              "wird works entirely on your device out of the box. No account is required to use it. It shows no "
                  "ads and runs no analytics or trackers. Your reading position, streak, hasanat, bookmarks and "
                  "saved verses are written to storage on your phone and never leave it, unless you turn on one of "
                  "the two optional features below.",
            ),
            section(
              'Friends (optional, off by default)',
              "If you open the Friends tab and choose to enable it, wird creates an anonymous account and shares "
                  "only the numbers you choose to show (streak, ayahs read, hasanat) with the friends you add by "
                  "code. It never shares which specific verses you've read. Friends is entirely separate from the "
                  "backup feature below - enabling one does not enable the other.",
            ),
            section(
              'Google backup (optional, off by default)',
              "If you choose to sign in with Google from Profile > Back up your data, wird stores a copy of your "
                  "reading streak, hasanat, day-by-day stats, bookmarks and saved verses - identified by your "
                  "Google account's email address - so reinstalling the app or switching phones can bring them "
                  "back. This never includes which specific ayahs you're reading moment to moment, and wird never "
                  "sees or stores your Google password or anything else from your Google account.",
            ),
            section(
              'Where that data is stored',
              "The optional data described above is stored using Google Firebase (Google Cloud infrastructure), "
                  "under an account only you control. Nobody else - not other wird users, not us - can read your "
                  "backup. See Google's own privacy policy for how Firebase processes data on our behalf: "
                  "policies.google.com/privacy.",
            ),
            section(
              'How long we keep it, and your choices',
              "There's no separate time limit - a backup is kept for as long as your account exists, until you "
                  "delete it yourself or ask us to. You can delete your backup at any time from Profile > Back up "
                  "your data > Delete backup & sign out - this permanently removes it from our servers; what's on "
                  "your device is never affected. You can also email us to request deletion of any data tied to "
                  "your account, and we'll act on it promptly. Never opening Friends or Backup means none of this "
                  "section ever applies to you.",
            ),
            section(
              'Third parties',
              "We use Google Firebase to operate Friends and Backup - no other third party ever receives your "
                  "data. We don't sell data, show ads, or run analytics or trackers of any kind.",
            ),
            section(
              'Children',
              "wird is not directed at children under 13, and we don't knowingly collect personal information "
                  "from anyone under that age through Google Sign-In or any other feature.",
            ),
            section(
              'Changes to this policy',
              "If anything here changes, we'll update this page and the date at the top.",
            ),
            section(
              'Contact',
              "Questions or a deletion request: afnan.wird@gmail.com",
            ),
          ],
        ),
      ),
    );
  }
}
