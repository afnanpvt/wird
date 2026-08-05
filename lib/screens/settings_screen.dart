import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;

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
      appBar: AppBar(elevation: 0, title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('APPEARANCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
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
          Text('YOUR NAME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(
            "Used to greet you on the home screen. Leave blank if you'd rather not.",
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Your name',
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (value) => context.read<AppState>().saveName(value),
          ),
          const SizedBox(height: 40),
          Text('YOUR DATA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(
            'Your reading position, streak, and stats are stored only on this device, never sent anywhere. '
            "They're kept permanently and will only be lost if you uninstall wird.",
            style: TextStyle(fontSize: 14, height: 1.5, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
