import 'package:flutter/material.dart';

import '../config/feature_flags.dart';
import '../services/feedback_service.dart';

/// App credit, third-party attribution, and feedback - deliberately its
/// own screen rather than inline on Profile, the way most apps tuck this
/// away in Settings > About instead of surfacing it to everyone scrolling
/// their own profile.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Image.asset(
            Theme.of(context).brightness == Brightness.dark
                ? 'assets/images/logo_foreground_dark.png'
                : 'assets/images/logo_foreground.png',
            height: 44,
          ),
          const SizedBox(height: 10),
          Text('built by afnan', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          // Attribution for bundled third-party text/fonts/audio - the
          // IndoPak font's own licence asks for a courtesy credit
          // somewhere users can find it, which is here.
          Text(
            'Quran text: QuranWBW IndoPak and Tanzil Uthmani.\n'
            'Arabic type: Amiri, AlQuran IndoPak by QuranWBW.\n'
            'Recitation: everyayah.com.',
            style: TextStyle(fontSize: 12.5, height: 1.7, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          if (FeatureFlags.friendsEnabled) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.onSurface,
                  foregroundColor: colorScheme.surface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (context) => const _FeedbackSheet(),
                ),
                child: const Text('Send feedback'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('or email', style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          SelectableText(
            'afnan.wird@gmail.com',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _service = FeedbackService();
  final _controller = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.suggestion;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _controller.text.trim();
    if (message.isEmpty) {
      setState(() => _error = "Mind adding a few words first?");
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _service.submit(message: message, category: _category);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
    } catch (e, stack) {
      debugPrint('Feedback submit failed: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = "Couldn't send that - mind trying again?";
      });
    }
  }

  static const _categoryLabels = {
    FeedbackCategory.bug: 'Bug',
    FeedbackCategory.suggestion: 'Suggestion',
    FeedbackCategory.other: 'Something else',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_sent) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, color: colorScheme.primary, size: 32),
            const SizedBox(height: 16),
            Text('Thank you', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              "This goes straight to our team - every note like this shapes what wird becomes next.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Send feedback', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
          const SizedBox(height: 6),
          Text(
            "What's on your mind? A bug, an idea, anything at all.",
            style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final cat in FeedbackCategory.values)
                ChoiceChip(
                  label: Text(_categoryLabels[cat]!),
                  selected: _category == cat,
                  onSelected: (_) => setState(() => _category = cat),
                  showCheckmark: false,
                  backgroundColor: colorScheme.surfaceContainerLow,
                  selectedColor: colorScheme.onSurface,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _category == cat ? colorScheme.surface : colorScheme.onSurfaceVariant,
                  ),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            minLines: 3,
            decoration: InputDecoration(
              hintText: 'Type here...',
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.onSurface,
              foregroundColor: colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: _sending ? null : _submit,
            child: _sending
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.surface),
                  )
                : const Text('Send'),
          ),
        ],
      ),
    );
  }
}
