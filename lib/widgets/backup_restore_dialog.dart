import 'package:flutter/material.dart';

import '../models/backup_snapshot.dart';
import '../utils/backup_formatting.dart';

/// A summary of what a found backup contains, with an explicit choice
/// between restoring it and keeping whatever's already on this device -
/// restoring never happens silently. Shared by onboarding's optional
/// backup step and the Backup screen's manual restore.
Future<bool?> showRestoreBackupDialog(BuildContext context, BackupSnapshot remote) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restore this backup?'),
      content: Text(
        'Backup from ${formatBackupDate(remote.backedUpAt)}: '
        '${remote.streakState.currentStreak}-day streak, '
        '${remote.totalHasanat} hasanat, '
        "${remote.bookmarks.length} bookmark${remote.bookmarks.length == 1 ? '' : 's'}.\n\n"
        "Restoring replaces what's currently on this device with this backup. This can't be undone.",
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep this device')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Restore')),
      ],
    ),
  );
}
