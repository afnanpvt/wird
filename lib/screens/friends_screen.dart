import 'package:flutter/material.dart';

import '../models/avatar_seeds.dart';
import '../models/friend_profile.dart';
import '../services/friends_service.dart';
import '../widgets/friend_avatar.dart';

/// Entry point for the whole Friends feature (see docs/superpowers/specs/
/// 2026-09-09-friends-social-design.md). There is no separate on/off
/// setting - this tab is always present, and completing the one-time setup
/// below (pick an avatar) is itself the opt-in. Never opening this screen
/// means never provisioning a Firebase Auth account or Firestore profile.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _service = FriendsService();
  late Future<FriendProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<FriendProfile?> _loadProfile() async {
    final hasProfile = await _service.hasProfile();
    if (!hasProfile) return null;
    return _service.getOwnProfile();
  }

  void _onSetupComplete(FriendProfile profile) => setState(() => _profileFuture = Future.value(profile));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Friends')),
      body: FutureBuilder<FriendProfile?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data;
          if (profile == null) {
            return _FriendsSetup(service: _service, onComplete: _onSetupComplete);
          }
          return _FriendsHome(service: _service, profile: profile);
        },
      ),
    );
  }
}

/// One-time setup: pick a predefined avatar, done. Creating the profile is
/// what opts this device in - see the class doc above.
class _FriendsSetup extends StatefulWidget {
  final FriendsService service;
  final ValueChanged<FriendProfile> onComplete;

  const _FriendsSetup({required this.service, required this.onComplete});

  @override
  State<_FriendsSetup> createState() => _FriendsSetupState();
}

class _FriendsSetupState extends State<_FriendsSetup> {
  String? _selectedSeed;
  bool _creating = false;
  String? _error;

  Future<void> _confirm() async {
    if (_selectedSeed == null) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final profile = await widget.service.createProfile(avatarSeed: _selectedSeed!);
      if (!mounted) return;
      widget.onComplete(profile);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = "Couldn't set up Friends - check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Pick an avatar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(
            'This is how friends will see you. You can add friends and see a friends-only leaderboard once set up.',
            style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              for (final seed in avatarSeeds)
                _AvatarChoice(
                  seed: seed,
                  selected: seed == _selectedSeed,
                  onTap: () => setState(() => _selectedSeed = seed),
                ),
            ],
          ),
          const SizedBox(height: 24),
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
            onPressed: (_selectedSeed == null || _creating) ? null : _confirm,
            child: _creating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.surface),
                  )
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  final String seed;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarChoice({required this.seed, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? colorScheme.primary : Colors.transparent, width: 2),
        ),
        child: FriendAvatar(seed: seed, size: 56),
      ),
    );
  }
}

/// The full Friends home once a profile exists: friend code / add friend,
/// incoming requests, leaderboard, and visibility settings.
class _FriendsHome extends StatefulWidget {
  final FriendsService service;
  final FriendProfile profile;

  const _FriendsHome({required this.service, required this.profile});

  @override
  State<_FriendsHome> createState() => _FriendsHomeState();
}

class _FriendsHomeState extends State<_FriendsHome> {
  late FriendProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  Future<void> _addFriend() async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _AddFriendDialog(),
    );
    if (code == null || code.trim().isEmpty) return;
    try {
      await widget.service.sendFriendRequestByCode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ArgumentError ? '${e.message}' : "Couldn't send request")),
      );
    }
  }

  Future<void> _setOnline(bool online) async {
    setState(() => _profile = _copyProfile(friendsEnabled: online));
    await widget.service.setOnline(online);
  }

  Future<void> _setVisibility({bool? showStreak, bool? showAyahs, bool? showHasanat}) async {
    setState(() => _profile = _copyProfile(showStreak: showStreak, showAyahs: showAyahs, showHasanat: showHasanat));
    await widget.service.setFieldVisibility(showStreak: showStreak, showAyahs: showAyahs, showHasanat: showHasanat);
  }

  FriendProfile _copyProfile({bool? friendsEnabled, bool? showStreak, bool? showAyahs, bool? showHasanat}) =>
      FriendProfile(
        uid: _profile.uid,
        username: _profile.username,
        friendCode: _profile.friendCode,
        avatarSeed: _profile.avatarSeed,
        friendsEnabled: friendsEnabled ?? _profile.friendsEnabled,
        showStreak: showStreak ?? _profile.showStreak,
        showAyahs: showAyahs ?? _profile.showAyahs,
        showHasanat: showHasanat ?? _profile.showHasanat,
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _ProfileCard(profile: _profile, onAddFriend: _addFriend),
        const SizedBox(height: 32),
        _SectionLabel('VISIBILITY'),
        const SizedBox(height: 12),
        _VisibilityCard(profile: _profile, onOnlineChanged: _setOnline, onFieldChanged: _setVisibility),
        const SizedBox(height: 32),
        _SectionLabel('REQUESTS'),
        const SizedBox(height: 12),
        _RequestsList(service: widget.service),
        const SizedBox(height: 32),
        _SectionLabel('LEADERBOARD'),
        const SizedBox(height: 8),
        Text(
          "Only visible to friends who've chosen to show each stat.",
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _Leaderboard(service: widget.service),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

class _ProfileCard extends StatelessWidget {
  final FriendProfile profile;
  final VoidCallback onAddFriend;

  const _ProfileCard({required this.profile, required this.onAddFriend});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FriendAvatar(seed: profile.avatarSeed, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Your code: ${profile.friendCode}',
                      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onAddFriend, child: const Text('Add a friend')),
        ],
      ),
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  final FriendProfile profile;
  final ValueChanged<bool> onOnlineChanged;
  final void Function({bool? showStreak, bool? showAyahs, bool? showHasanat}) onFieldChanged;

  const _VisibilityCard({required this.profile, required this.onOnlineChanged, required this.onFieldChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Online to friends'),
            subtitle: const Text('Off hides you completely and pauses nudges'),
            value: profile.friendsEnabled,
            onChanged: onOnlineChanged,
          ),
          if (profile.friendsEnabled) ...[
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Show streak'),
              value: profile.showStreak,
              onChanged: (v) => onFieldChanged(showStreak: v),
            ),
            SwitchListTile(
              title: const Text('Show ayahs read'),
              value: profile.showAyahs,
              onChanged: (v) => onFieldChanged(showAyahs: v),
            ),
            SwitchListTile(
              title: const Text('Show hasanat'),
              value: profile.showHasanat,
              onChanged: (v) => onFieldChanged(showHasanat: v),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddFriendDialog extends StatefulWidget {
  const _AddFriendDialog();

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a friend'),
      content: TextField(
        controller: _controller,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'e.g. WIRD-7F3K2'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Send request')),
      ],
    );
  }
}

class _RequestsList extends StatelessWidget {
  final FriendsService service;
  const _RequestsList({required this.service});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<FriendRequest>>(
      stream: service.incomingRequests(),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const [];
        if (requests.isEmpty) {
          return Text('No pending requests', style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant));
        }
        return Column(
          children: [
            for (final request in requests)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Expanded(child: Text(request.fromUsername, style: const TextStyle(fontWeight: FontWeight.w600))),
                    IconButton(
                      icon: const Icon(Icons.check_circle_rounded),
                      color: colorScheme.primary,
                      onPressed: () => service.acceptFriendRequest(request.fromUid),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined),
                      onPressed: () => service.declineFriendRequest(request.fromUid),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Leaderboard extends StatelessWidget {
  final FriendsService service;
  const _Leaderboard({required this.service});

  Future<List<LeaderboardEntry>> _load(List<String> friendUids) async {
    final entries = <LeaderboardEntry>[];
    for (final uid in friendUids) {
      final profile = await service.getProfile(uid);
      if (profile == null || !profile.friendsEnabled) continue;
      final stats = await service.getStats(uid);
      entries.add(LeaderboardEntry.from(profile, stats));
    }
    entries.sort((a, b) {
      final streakCompare = (b.streak ?? -1).compareTo(a.streak ?? -1);
      if (streakCompare != 0) return streakCompare;
      return (b.hasanatThisWeek ?? -1).compareTo(a.hasanatThisWeek ?? -1);
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<String>>(
      stream: service.friendUids(),
      builder: (context, friendsSnapshot) {
        final friendUids = friendsSnapshot.data ?? const [];
        if (friendUids.isEmpty) {
          return Text('Add a friend to see the leaderboard', style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant));
        }
        return FutureBuilder<List<LeaderboardEntry>>(
          future: _load(friendUids),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final entries = snapshot.data!;
            return Column(
              children: [
                for (final entry in entries)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        FriendAvatar(seed: entry.avatarSeed, size: 36),
                        const SizedBox(width: 12),
                        Expanded(child: Text(entry.username, style: const TextStyle(fontWeight: FontWeight.w600))),
                        _StatChip(icon: Icons.local_fire_department_rounded, value: entry.streak),
                        const SizedBox(width: 8),
                        _StatChip(icon: Icons.menu_book_rounded, value: entry.ayahsThisWeek),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int? value;
  const _StatChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(value == null ? '-' : '$value', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
