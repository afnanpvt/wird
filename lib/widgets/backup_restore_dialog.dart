import 'package:flutter/material.dart';

import '../models/backup_snapshot.dart';
import '../services/app_state.dart';
import '../services/backup_service.dart';
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

/// The full "sign in with Google, offer to restore if a backup already
/// exists for that account, otherwise push a fresh one" sequence - shared
/// by every place that offers Google sign-in (onboarding, the reminder
/// sheet, the Backup screen), so there's exactly one place this logic lives
/// rather than three slightly-drifting copies. Returns null if the user
/// cancelled Google's own account picker; otherwise the snapshot now
/// backing this device (either the one just restored, or a freshly pushed
/// current one) - callers use that to update their own "last synced" UI.
Future<BackupSnapshot?> runBackupSignInFlow(BuildContext context, BackupService service, AppState appState) async {
  final outcome = await service.signInWithGoogle();
  if (outcome == BackupSignInOutcome.cancelled) return null;
  if (!context.mounted) return null;

  final remote = await service.fetchBackup();
  if (remote != null && context.mounted) {
    final shouldRestore = await showRestoreBackupDialog(context, remote);
    if (shouldRestore == true) {
      await appState.restoreFromBackup(remote);
      return remote;
    }
  }

  final snapshot = appState.currentBackupSnapshot();
  await service.pushBackup(snapshot);
  return snapshot;
}
