import 'package:flutter/material.dart';

Future<void> showWelcomeDialog(BuildContext context, {required bool isFirstLaunch}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/images/logo_foreground_dark.png'
                  : 'assets/images/logo_foreground.png',
              height: 52,
            ),
            const SizedBox(height: 16),
            Text(
              isFirstLaunch ? 'Welcome to wird.' : 'Welcome back',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              isFirstLaunch
                  ? "Glad you're here. Take it one ayah at a time, there's no rush and no one's watching but you."
                  : "Good to see you again. Whatever you read today counts, even if it's just one verse.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.onSurface,
                  foregroundColor: colorScheme.surface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(isFirstLaunch ? "Let's begin" : 'Continue'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
