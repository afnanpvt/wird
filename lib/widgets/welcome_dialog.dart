import 'package:flutter/material.dart';

Future<void> showWelcomeDialog(BuildContext context, {required bool isFirstLaunch}) {
  return showDialog(
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo_foreground.png', height: 40),
            const SizedBox(height: 16),
            Text(
              isFirstLaunch ? 'Welcome to wird.' : 'Welcome back',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              isFirstLaunch
                  ? "Glad you're here. Take it one ayah at a time, there's no rush and no one's watching but you."
                  : "Good to see you again. Whatever you read today counts, even if it's just one verse.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.onSurface,
                  foregroundColor: colorScheme.surface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(isFirstLaunch ? "Let's begin" : 'Continue'),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'BUILT BY AFNAN',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    },
  );
}
