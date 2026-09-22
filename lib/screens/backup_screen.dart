import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/backup_snapshot.dart';
import '../services/app_state.dart';
import '../services/backup_service.dart';
import '../utils/backup_formatting.dart';
import '../widgets/backup_restore_dialog.dart';
import '../widgets/google_sign_in_button.dart';
import 'privacy_screen.dart';

/// Google Sign-In backup/restore, reached from Profile > Back up your data
/// (and, the first time, offered as an optional step during onboarding -
/// see OnboardingScreen's _BackupStep, which shares the sign-in/restore
/// logic here via BackupService and AppState). Entirely optional and off by
/// default (see FeatureFlags.backupEnabled) - this is the only place a
/// Google account ever gets involved, and the only place data leaves the
/// device for this feature specifically (separate from, and unaffected by,
/// the Friends tab).
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
      final outcome = await _service.signInWithGoogle();
      if (outcome == BackupSignInOutcome.cancelled) {
        setState(() => _working = false);
        return;
      }
      if (!mounted) return;
      final appState = context.read<AppState>();
      final remote = await _service.fetchBackup();
      var restored = false;
      if (remote != null && mounted) {
        final shouldRestore = await showRestoreBackupDialog(context, remote);
        if (shouldRestore == true) {
          await appState.restoreFromBackup(remote);
          restored = true;
        }
      }
      // Always push right after sign-in too: a first-time signer-upper (no
      // remote backup found) gets one immediately, and one who declined the
      // restore still ends up with something backed up either way.
      final pushed = restored ? remote! : appState.currentBackupSnapshot();
      if (!restored) await _service.pushBackup(pushed);
      if (!mounted) return;
      setState(() {
        _working = false;
        _signedIn = true;
        _lastKnownBackup = pushed;
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
      appBar: AppBar(elevation: 0, title: const Text('Back up your data')),
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
        Icon(Icons.cloud_outlined, size: 32, color: colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          "Keep your reading safe if you lose this phone",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          "By default wird lives only on this device - uninstalling it erases everything. Signing in with Google "
          "backs up your streak, hasanat, day-by-day stats, bookmarks and saved verses, so reinstalling wird (even "
          "on a new phone) can bring them back.",
          style: TextStyle(fontSize: 13.5, height: 1.4, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          "What's never included: which specific ayahs you're reading in the moment, or anything from your Google "
          "account beyond your email - no ads, no analytics, nothing sold or shared. You can delete this backup "
          "anytime from this screen.",
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

  List<Widget> _buildSignedIn(ColorScheme colorScheme) => [
        Icon(Icons.cloud_done_outlined, size: 32, color: colorScheme.primary),
        const SizedBox(height: 16),
        Text('Backed up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
        const SizedBox(height: 4),
        if (_service.accountEmail != null)
          Text(_service.accountEmail!, style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(
          'Last backed up: ${formatBackupDate(_lastKnownBackup?.backedUpAt)}',
          style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.onSurface,
            foregroundColor: colorScheme.surface,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: const StadiumBorder(),
          ),
          onPressed: _working ? null : _backUpNow,
          child: _working
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.surface))
              : const Text('Back up now'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: const StadiumBorder()),
          onPressed: _working ? null : _restoreLatest,
          child: const Text('Restore latest backup'),
        ),
        const SizedBox(height: 32),
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
