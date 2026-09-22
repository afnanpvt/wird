import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/feature_flags.dart';
import '../models/quran_script.dart';
import '../models/reciter.dart';
import '../services/app_state.dart';
import '../services/friends_service.dart';
import '../widgets/avatar_picker_grid.dart';
import '../widgets/profile_avatar.dart';
import 'about_screen.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  final _friendsService = FeatureFlags.friendsEnabled ? FriendsService() : null;
  bool _showAvatarPicker = false;
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: context.read<AppState>().userName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectAvatar(String seed) async {
    setState(() => _showAvatarPicker = false);
    await context.read<AppState>().setAvatarSeed(seed);
    // Keeps the published Friends profile's avatar in sync, if Friends is
    // already enabled - a no-op otherwise (see updateAvatarSeed's doc).
    await _friendsService?.updateAvatarSeed(seed);
  }

  Future<void> _confirmName() async {
    final name = _nameController.text.trim();
    setState(() => _editingName = false);
    await context.read<AppState>().saveName(name);
    // Keeps the published Friends profile's name in sync, if Friends is
    // already enabled - a no-op otherwise (see updateDisplayName's doc).
    if (name.isNotEmpty) await _friendsService?.updateDisplayName(name);
  }

  /// Describes exactly what happens to reading data given which optional
  /// cloud features (if any) are compiled into this build - keeps this
  /// promise accurate rather than a blanket claim that stops being true the
  /// moment either feature is turned on. See PrivacyScreen for the full
  /// policy this summarizes.
  String _yourDataCopy() {
    final parts = <String>['Your reading position, streak, and stats are stored on this device and kept permanently.'];
    if (FeatureFlags.friendsEnabled) {
      parts.add(
        'If you add friends, only your streak, ayah count, and hasanat (never what you actually read) are shared '
        'with them - and only what you choose to show.',
      );
    }
    if (FeatureFlags.backupEnabled) {
      parts.add(
        "If you turn on Google backup, a copy is also kept under your Google account so reinstalling wird - even "
        "on a new phone - can bring it back. Off until you turn it on, and deletable anytime from that screen.",
      );
    }
    if (!FeatureFlags.friendsEnabled && !FeatureFlags.backupEnabled) {
      parts.add("Nothing is ever sent anywhere - it will only be lost if you uninstall wird.");
    }
    return parts.join(' ');
  }

  static const _themeLabels = {
    AppThemeMode.system: 'System',
    AppThemeMode.light: 'Light',
    AppThemeMode.dark: 'Dark',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          // Identity: avatar + name, the one thing every profile screen
          // leads with - everything else (appearance, script, reciter) is
          // a preference, not who you are.
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showAvatarPicker = !_showAvatarPicker),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      if (appState.avatarSeed != null)
                        ProfileAvatar(seed: appState.avatarSeed!, size: 96)
                      else
                        CircleAvatar(radius: 48, backgroundColor: colorScheme.surfaceContainerLow),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.onSurface,
                          border: Border.all(color: colorScheme.surface, width: 2),
                        ),
                        child: Icon(Icons.edit_rounded, size: 14, color: colorScheme.surface),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_editingName)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _nameController,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.words,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(hintText: 'Your name', isDense: true),
                          onSubmitted: (_) => _confirmName(),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.check_rounded), onPressed: _confirmName),
                    ],
                  )
                else
                  GestureDetector(
                    onTap: () => setState(() => _editingName = true),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          appState.userName?.isNotEmpty == true ? appState.userName! : 'Add your name',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: appState.userName?.isNotEmpty == true ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_rounded, size: 15, color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_showAvatarPicker) ...[
            const SizedBox(height: 20),
            AvatarPickerGrid(selectedSeed: appState.avatarSeed, onSelect: _selectAvatar),
          ],
          const SizedBox(height: 40),
          Text('APPEARANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          SegmentedButton<AppThemeMode>(
            segments: AppThemeMode.values
                .map((mode) => ButtonSegment(value: mode, label: Text(_themeLabels[mode]!)))
                .toList(),
            selected: {appState.themeMode},
            onSelectionChanged: (selection) => appState.saveThemeMode(selection.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: colorScheme.onSurface,
              selectedForegroundColor: colorScheme.surface,
            ),
          ),
          const SizedBox(height: 40),
          Text('QURAN SCRIPT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final script in QuranScript.values) ...[
            _ScriptOption(
              script: script,
              selected: appState.quranScript == script,
              onTap: () => appState.setScript(script),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 40),
          Text('RECITER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(
            'Who recites the verse audio while reading.',
            style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final r in Reciter.values) ...[
            _ReciterOption(
              reciter: r,
              selected: appState.reciter == r,
              onTap: () => appState.setReciter(r),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 40),
          Text('YOUR DATA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(_yourDataCopy(), style: TextStyle(fontSize: 13.5, height: 1.5, color: colorScheme.onSurface)),
          if (FeatureFlags.backupEnabled) ...[
            const SizedBox(height: 12),
            Material(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_outlined, size: 20, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Back up your data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                      Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
              style: TextButton.styleFrom(foregroundColor: colorScheme.onSurfaceVariant),
              child: const Text('About wird', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReciterOption extends StatelessWidget {
  final Reciter reciter;
  final bool selected;
  final VoidCallback onTap;

  const _ReciterOption({required this.reciter, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? colorScheme.primary : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(reciter.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScriptOption extends StatelessWidget {
  final QuranScript script;
  final bool selected;
  final VoidCallback onTap;

  const _ScriptOption({required this.script, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? colorScheme.primary : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(script.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(script.description, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    Text(
                      script.previewText,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontFamily: script.fontFamily, fontSize: 20, height: 1.8, color: colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
