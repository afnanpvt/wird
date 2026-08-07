import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quran_script.dart';
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
          Text('QURAN SCRIPT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final script in QuranScript.values) ...[
            _ScriptOption(
              script: script,
              selected: appState.quranScript == script,
              onTap: () => appState.setScript(script),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 30),
          Text('YOUR DATA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(
            'Your reading position, streak, and stats are stored only on this device, never sent anywhere. '
            "They're kept permanently and will only be lost if you uninstall wird.",
            style: TextStyle(fontSize: 14, height: 1.5, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 48),
          Text('ABOUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/images/logo_foreground_dark.png'
                    : 'assets/images/logo_foreground.png',
                height: 44,
              ),
              const SizedBox(height: 8),
              Text('built by afnan', style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 20),
          Text('feedback or issues', style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          SelectableText(
            'afnan.wird@gmail.com',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
        ],
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
                      _preview,
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

const _preview = 'بِسْمِ اللَّهِ الرَّحْمٰنِ الرَّحِيمِ';
