import 'package:flutter/material.dart';

String _formatWithCommas(int n) {
  final digits = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

Future<void> showCompletionDialog(
  BuildContext context, {
  required int ayahsThisSession,
  required int ayahsToday,
  required int hasanatThisSession,
}) {
  // A short session (a page or two before stopping) hasn't earned
  // congratulating - only genuinely substantive sessions get the praise.
  final title = ayahsThisSession < 5 ? "Today's reading" : 'Nice work today';
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(
        '$ayahsThisSession ayah${ayahsThisSession == 1 ? '' : 's'} read this session\n'
        '$ayahsToday ayah${ayahsToday == 1 ? '' : 's'} read today\n'
        '${_formatWithCommas(hasanatThisSession)} hasanat earned this session',
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
