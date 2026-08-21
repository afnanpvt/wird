import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quran_script.dart';
import '../services/app_state.dart';
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

  static const _totalSteps = 3;

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
    await appState.completeOnboarding(name: _nameController.text, script: _selectedScript);
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
                  _ScriptStep(
                    selected: _selectedScript,
                    onSelect: (s) => setState(() => _selectedScript = s),
                    onNext: () => _goTo(2),
                    onBack: () => _goTo(0),
                  ),
                  _WelcomeStep(name: _nameController.text.trim(), onFinish: _finish),
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
                Text('wird.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colorScheme.primary)),
                const SizedBox(height: 20),
                const Text("What should we call you?", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 8),
                Text(
                  "So your greeting feels like it's actually for you. You can skip this if you'd rather not.",
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
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
          ),
          const SizedBox(height: 8),
          const Text('Which script feels like home?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 8),
          Text(
            'You can change this anytime in Settings.',
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
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? colorScheme.primary : Colors.transparent, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
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

class _WelcomeStep extends StatelessWidget {
  final String name;
  final VoidCallback onFinish;

  const _WelcomeStep({required this.name, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final greetingName = name.isEmpty ? '' : ', $name';
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.scale(scale: 0.9 + value * 0.1, child: child),
            ),
            child: Image.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/images/logo_foreground_dark.png'
                  : 'assets/images/logo_foreground.png',
              height: 48,
            ),
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
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
