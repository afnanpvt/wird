import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/backup_snapshot.dart';
import '../services/app_state.dart';
import '../services/backup_service.dart';
import '../utils/backup_formatting.dart';
import '../widgets/backup_restore_dialog.dart';
import '../widgets/google_sign_in_button.dart';
import 'privacy_screen.dart';

/// Google Sign-In, reached from Profile > Account (and, the first time,
/// offered as an optional step during onboarding - see OnboardingScreen's
/// _BackupStep, which shares the sign-in/restore logic here via
/// BackupService and AppState). Keeping your streak/hasanat/bookmarks tied
/// to your account isn't framed as a separate "backup" feature to turn on -
/// it's just what being signed in means, same as any other app. Entirely
/// optional and off by default (see FeatureFlags.backupEnabled).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final BackupService _service;
  bool _signedIn = false;
  bool _working = false;
  String? _error;
  BackupSnapshot? _lastKnownBackup;

  @override
  void initState() {
    super.initState();
    _service = context.read<AppState>().backupService!;
    _signedIn = _service.isSignedIn;
    if (_signedIn) _loadStatus();
  }

  Future<void> _loadStatus() async {
    final remote = await _service.fetchBackup();
    if (!mounted) return;
    setState(() => _lastKnownBackup = remote);
  }

  Future<void> _signIn() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      final snapshot = await runBackupSignInFlow(context, _service, appState);
      if (!mounted) return;
      if (snapshot == null) {
        // Cancelled Google's own picker - not an error, just back to rest.
        setState(() => _working = false);
        return;
      }
      setState(() {
        _working = false;
        _signedIn = true;
        _lastKnownBackup = snapshot;
      });
    } catch (e, stack) {
      debugPrint('Backup sign-in failed: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = "Something went wrong signing in - mind trying again?";
      });
    }
  }

  Future<void> _backUpNow() async {
    setState(() => _working = true);
    final snapshot = context.read<AppState>().currentBackupSnapshot();
    await _service.pushBackup(snapshot);
    if (!mounted) return;
    setState(() {
      _working = false;
      _lastKnownBackup = snapshot;
    });
  }

  Future<void> _restoreLatest() async {
    setState(() => _working = true);
    final remote = await _service.fetchBackup();
    if (!mounted) return;
    setState(() => _working = false);
    if (remote == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No backup found for this account')));
      return;
    }
    final confirmed = await showRestoreBackupDialog(context, remote);
    if (confirmed != true || !mounted) return;
    await context.read<AppState>().restoreFromBackup(remote);
    if (!mounted) return;
    setState(() => _lastKnownBackup = remote);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restored')));
  }

  Future<void> _signOut() async {
    await _service.signOut();
    if (!mounted) return;
    setState(() {
      _signedIn = false;
      _lastKnownBackup = null;
    });
  }

  Future<void> _deleteAndSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete backup and sign out?'),
        content: const Text(
          "This permanently deletes the copy of your streak, hasanat, bookmarks and saved verses stored for this "
          "account - what's on this device right now is not affected.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteBackupAndSignOut();
    if (!mounted) return;
    setState(() {
      _signedIn = false;
      _lastKnownBackup = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!_signedIn) ..._buildSignedOut(colorScheme) else ..._buildSignedIn(colorScheme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSignedOut(ColorScheme colorScheme) => [
        Text(
          'Sign in with Google',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          "Ties your streak, hasanat, bookmarks and saved verses to your account, so a reinstall or a new phone "
          "picks up where you left off. Never includes which ayahs you're reading, and nothing from your Google "
          "account beyond your email.",
          style: TextStyle(fontSize: 13.5, height: 1.4, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: colorScheme.error)),
          const SizedBox(height: 12),
        ],
        GoogleSignInButton(loading: _working, onPressed: _working ? null : _signIn),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
            style: TextButton.styleFrom(foregroundColor: colorScheme.onSurfaceVariant),
            child: const Text('Privacy policy', style: TextStyle(fontSize: 12.5)),
          ),
        ),
      ];

  // Leads with status, not an action - there's nothing to "do" day to day,
  // it just stays synced (see AppState._pushBackupIfSignedIn, called after
  // every read/bookmark/favorite change). "Sync now" further down is a
  // small, secondary reassurance for right after being offline, the same
  // supporting role iCloud's own "Back Up Now" plays under its own always-on
  // status line - never the primary action, because there isn't one.
  List<Widget> _buildSignedIn(ColorScheme colorScheme) => [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_service.accountEmail != null)
                Text(_service.accountEmail!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
              const SizedBox(height: 10),
              Divider(height: 1, color: colorScheme.outlineVariant),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Last synced: ${formatBackupDate(_lastKnownBackup?.backedUpAt)}',
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  if (_working)
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onSurfaceVariant))
                  else
                    GestureDetector(
                      onTap: _backUpNow,
                      child: Text('Sync now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.primary)),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Every read, bookmark and saved verse pushes up on its own - there's nothing to remember to do. "
          "If you're setting up a new phone, pull the last one down instead.",
          style: TextStyle(fontSize: 13, height: 1.5, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: const StadiumBorder()),
          onPressed: _working ? null : _restoreLatest,
          child: const Text('Restore on this device'),
        ),
        const SizedBox(height: 40),
        Center(
          child: TextButton(
            onPressed: _working ? null : _signOut,
            style: TextButton.styleFrom(foregroundColor: colorScheme.onSurfaceVariant),
            child: const Text('Sign out'),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _working ? null : _deleteAndSignOut,
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Delete backup & sign out'),
          ),
        ),
      ];
}
