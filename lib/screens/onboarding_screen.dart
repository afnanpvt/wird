import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/feature_flags.dart';
import '../models/avatar_seeds.dart';
import '../models/quran_script.dart';
import '../services/app_state.dart';
import '../services/backup_service.dart';
import '../widgets/avatar_picker_grid.dart';
import '../widgets/backup_restore_dialog.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/profile_avatar.dart';
import 'root_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  int _step = 0;
  QuranScript _selectedScript = QuranScript.indoPakNastaleeq;
  String _selectedAvatarSeed = avatarSeeds.first;

  // One extra step - the optional Google backup offer - only when that
  // feature is actually compiled in (see FeatureFlags.backupEnabled); a
  // build without it never shows a sign-in button it can't back up yet.
  static const _totalSteps = FeatureFlags.backupEnabled ? 5 : 4;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    final appState = context.read<AppState>();
    await appState.completeOnboarding(
      name: _nameController.text,
      script: _selectedScript,
      avatarSeed: _selectedAvatarSeed,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RootScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _totalSteps; i++) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    width: i == _step ? 28 : 16,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i <= _step ? colorScheme.primary : colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ],
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _NameStep(controller: _nameController, onNext: () => _goTo(1)),
                  _AvatarStep(
                    name: _nameController.text.trim(),
                    selected: _selectedAvatarSeed,
                    onSelect: (seed) => setState(() => _selectedAvatarSeed = seed),
                    onNext: () => _goTo(2),
                    onBack: () => _goTo(0),
                  ),
                  _ScriptStep(
                    selected: _selectedScript,
                    onSelect: (s) => setState(() => _selectedScript = s),
                    onNext: () => _goTo(3),
                    onBack: () => _goTo(1),
                  ),
                  if (FeatureFlags.backupEnabled)
                    _BackupStep(onNext: () => _goTo(4), onBack: () => _goTo(2)),
                  _WelcomeStep(
                    name: _nameController.text.trim(),
                    avatarSeed: _selectedAvatarSeed,
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onNext;

  const _NameStep({required this.controller, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, (1 - value) * 16), child: child)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                    children: [
                      const TextSpan(text: 'wird'),
                      TextSpan(text: '.', style: TextStyle(color: colorScheme.primary)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Assalamu alaikum! What should we call you?", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 8),
                Text(
                  "We'll use it to make this feel like your own space, not just an app.",
                  style: TextStyle(fontSize: 14, height: 1.4, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Your name',
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            onSubmitted: (_) => onNext(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
              ),
              onPressed: onNext,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarStep extends StatelessWidget {
  final String name;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _AvatarStep({required this.name, required this.selected, required this.onSelect, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final greeting = name.isEmpty ? 'Nice to meet you' : 'Nice to meet you, $name';
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
          ),
          const SizedBox(height: 8),
          Text('$greeting - pick a face to go with it', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 8),
          Text(
            "You can change it anytime later.",
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 36),
          Center(child: AvatarPickerGrid(selectedSeed: selected, onSelect: onSelect)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
              ),
              onPressed: onNext,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScriptStep extends StatelessWidget {
  final QuranScript selected;
  final ValueChanged<QuranScript> onSelect;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _ScriptStep({required this.selected, required this.onSelect, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
          ),
          const SizedBox(height: 8),
          const Text('Which script feels like home?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 8),
          Text(
            'You can change this anytime in your Profile.',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                for (final script in QuranScript.values) ...[
                  _ScriptCard(script: script, selected: script == selected, onTap: () => onSelect(script)),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
              ),
              onPressed: onNext,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScriptCard extends StatelessWidget {
  final QuranScript script;
  final bool selected;
  final VoidCallback onTap;

  const _ScriptCard({required this.script, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? colorScheme.primary : Colors.transparent, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(script.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(script.description, style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 10),
                      Text(
                        script.previewText,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontFamily: script.fontFamily, fontSize: 22, height: 1.8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The optional Google backup offer - only ever in the flow when
/// FeatureFlags.backupEnabled is compiled in (see OnboardingScreen). Never
/// blocks progress: signing in, restoring, an error, or "Skip for now" all
/// lead to the same next step. This is also the moment a *reinstall* is
/// most likely to matter - someone who backed up before, deleted the app,
/// and is back at onboarding with an empty device - so a found backup is
/// offered for restore right here, before they build up any new local data.
class _BackupStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _BackupStep({required this.onNext, required this.onBack});

  @override
  State<_BackupStep> createState() => _BackupStepState();
}

class _BackupStepState extends State<_BackupStep> {
  bool _working = false;
  String? _error;

  Future<void> _signIn() async {
    final appState = context.read<AppState>();
    final service = appState.backupService;
    if (service == null) {
      widget.onNext();
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final outcome = await service.signInWithGoogle();
      if (outcome == BackupSignInOutcome.cancelled) {
        setState(() => _working = false);
        return;
      }
      if (!mounted) return;
      final remote = await service.fetchBackup();
      if (remote != null && mounted) {
        final shouldRestore = await showRestoreBackupDialog(context, remote);
        if (shouldRestore == true) {
          await appState.restoreFromBackup(remote);
        } else {
          await service.pushBackup(appState.currentBackupSnapshot());
        }
      } else {
        await service.pushBackup(appState.currentBackupSnapshot());
      }
      if (!mounted) return;
      widget.onNext();
    } catch (e, stack) {
      debugPrint('Onboarding backup sign-in failed: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = "Something went wrong signing in - mind trying again, or skip for now?";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IconButton(
            onPressed: _working ? null : widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
          ),
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(offset: Offset(0, (1 - value) * 12), child: child),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.primary.withValues(alpha: 0.12)),
                  child: Icon(Icons.cloud_outlined, size: 32, color: colorScheme.primary),
                ),
                const SizedBox(height: 28),
                Text(
                  'Keep it, even if you delete the app',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 10),
                Text(
                  "Sign in with Google to back up your streak, hasanat and bookmarks, so a new phone or a "
                  "reinstall picks up right where you left off. Totally optional - skip it now and turn it on "
                  "anytime later from Profile.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.5, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (_error != null) ...[
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: colorScheme.error)),
            const SizedBox(height: 12),
          ],
          GoogleSignInButton(loading: _working, onPressed: _working ? null : _signIn),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _working ? null : widget.onNext,
              style: TextButton.styleFrom(foregroundColor: colorScheme.onSurfaceVariant),
              child: const Text('Skip for now'),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  final String name;
  final String avatarSeed;
  final VoidCallback onFinish;

  const _WelcomeStep({required this.name, required this.avatarSeed, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final greetingName = name.isEmpty ? '' : ', $name';
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The avatar and name they just picked, shown back to them here -
          // this is the moment onboarding actually pays off the identity
          // they just built, instead of ending on a generic logo screen
          // that ignores everything they just chose.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.scale(scale: 0.9 + value * 0.1, child: child),
            ),
            child: ProfileAvatar(seed: avatarSeed, size: 96),
          ),
          const SizedBox(height: 32),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, (1 - value) * 12), child: child)),
            child: Column(
              children: [
                Text(
                  "You're all set$greetingName",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 12),
                Text(
                  "One ayah a day is enough to start. We'll be right here keeping track, so all you have to do is show up.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
              ),
              onPressed: onFinish,
              child: const Text("Let's begin"),
            ),
          ),
        ],
      ),
    );
  }
}
