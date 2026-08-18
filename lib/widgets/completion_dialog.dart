import 'package:flutter/material.dart';

/// Compact so a large hasanat total never wraps the stat block - matches
/// the same abbreviation the reading screen's own running-total chip uses,
/// for the same reason (see _formatCompactHasanat in reading_screen.dart).
String _formatCompact(int n) {
  if (n < 1000) return '$n';
  if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '${(n / 1000).round()}k';
}

Future<void> showCompletionDialog(
  BuildContext context, {
  required int ayahsThisSession,
  required int ayahsToday,
  required int hasanatThisSession,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  // A short session (a page or two before stopping) hasn't earned
  // congratulating - only genuinely substantive sessions get the praise.
  final isSubstantive = ayahsThisSession >= 5;
  final title = isSubstantive ? 'Nice work today' : "Today's reading";

  return showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isSubstantive) ...[
              Icon(Icons.auto_awesome_rounded, color: colorScheme.primary, size: 28),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2),
            ),
            const SizedBox(height: 24),
            // Same stat-block treatment as the home screen's stats card
            // (bold numeral, muted label, hairline dividers, no nested
            // card) - the app's one established way of surfacing numbers.
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: '$ayahsThisSession',
                    label: 'this session',
                  ),
                ),
                SizedBox(width: 1, height: 40, child: Container(color: colorScheme.outlineVariant)),
                Expanded(
                  child: _Stat(
                    value: '$ayahsToday',
                    label: 'today',
                  ),
                ),
                SizedBox(width: 1, height: 40, child: Container(color: colorScheme.outlineVariant)),
                Expanded(
                  child: _Stat(
                    value: _formatCompact(hasanatThisSession),
                    label: 'hasanat',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.onSurface,
                  foregroundColor: colorScheme.surface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
