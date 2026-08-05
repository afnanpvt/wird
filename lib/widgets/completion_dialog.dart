import 'package:flutter/material.dart';

Future<void> showCompletionDialog(
  BuildContext context, {
  required int ayahsThisSession,
  required int ayahsToday,
}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Nice work today'),
      content: Text(
        '$ayahsThisSession ayah${ayahsThisSession == 1 ? '' : 's'} read this session\n'
        '$ayahsToday ayah${ayahsToday == 1 ? '' : 's'} read today',
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
