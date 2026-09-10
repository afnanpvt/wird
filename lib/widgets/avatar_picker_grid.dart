import 'package:flutter/material.dart';

import '../models/avatar_seeds.dart';
import 'profile_avatar.dart';

/// Grid of the fixed predefined avatars (see models/avatar_seeds.dart) -
/// shared by onboarding's avatar step and the Profile screen's "change
/// avatar" control, so both pick from the exact same set the same way.
class AvatarPickerGrid extends StatelessWidget {
  final String? selectedSeed;
  final ValueChanged<String> onSelect;

  const AvatarPickerGrid({super.key, required this.selectedSeed, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 4 * 76.0,
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          for (final seed in avatarSeeds)
            _AvatarChoice(
              seed: seed,
              selected: seed == selectedSeed,
              onTap: () => onSelect(seed),
            ),
        ],
      ),
    );
  }
}

class _AvatarChoice extends StatefulWidget {
  final String seed;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarChoice({required this.seed, required this.selected, required this.onTap});

  @override
  State<_AvatarChoice> createState() => _AvatarChoiceState();
}

class _AvatarChoiceState extends State<_AvatarChoice> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedScale(
        scale: widget.selected ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.selected ? colorScheme.primary.withValues(alpha: 0.16) : Colors.transparent,
            border: Border.all(color: widget.selected ? colorScheme.primary : Colors.transparent, width: 2),
          ),
          child: ProfileAvatar(seed: widget.seed, size: 56),
        ),
      ),
    );
  }
}
