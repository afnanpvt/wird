import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/friend_profile.dart';
import '../services/app_state.dart';
import '../services/friend_nudge_checker.dart';
import '../services/friends_service.dart';
import '../widgets/profile_avatar.dart';

/// Entry point for the whole Friends feature (see docs/superpowers/specs/
/// 2026-09-09-friends-social-design.md). There is no separate on/off
/// setting - this tab is always present, and tapping "Enable Friends"
/// below is itself the opt-in. Never tapping it means never provisioning a
/// Firebase Auth account or Firestore profile. Avatar and name are no
/// longer chosen here - they're core app identity set during onboarding
/// (or later from the Profile screen), and enabling Friends just publishes
/// whichever avatar is already set.
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

  void _onSetupComplete(FriendProfile profile) {
    setState(() {
      _profileFuture = Future.value(profile);
    });
    // Right after they've opted in is the one moment this explanation has
    // real context - asking cold, at first app launch, would mean the OS
    // permission dialog shows with no idea why it's even being asked.
    _offerNotifications();
  }

  Future<void> _offerNotifications() async {
    final wantsNotifications = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _NotificationsExplainerSheet(),
    );
    if (wantsNotifications == true) {
      await FriendNudgeChecker.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    // No outer Scaffold/AppBar here - both _FriendsSetup and _FriendsHome
    // below already have their own (the latter's carries the settings
    // gear icon), so this used to stack two "Friends" headers on top of
    // each other.
    return FutureBuilder<FriendProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final profile = snapshot.data;
        if (profile == null) {
          return _FriendsSetup(service: _service, onComplete: _onSetupComplete);
        }
        return _FriendsHome(service: _service, profile: profile);
      },
    );
  }
}

/// One tap to opt in: publishes the avatar and name already set on the
/// Profile screen under a freshly generated friend code. If no name is
/// set yet, asks for one first - Friends fundamentally needs a name to
/// show to other people, unlike the rest of the app where it's optional.
/// See the class doc above.
class _FriendsSetup extends StatefulWidget {
  final FriendsService service;
  final ValueChanged<FriendProfile> onComplete;

  const _FriendsSetup({required this.service, required this.onComplete});

  @override
  State<_FriendsSetup> createState() => _FriendsSetupState();
}

class _FriendsSetupState extends State<_FriendsSetup> {
  bool _creating = false;
  String? _error;
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

  Future<void> _confirm(String avatarSeed) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = "Friends needs a name to show your friends - what should we call you?");
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      if (appState.userName != name) await appState.saveName(name);
      final profile = await widget.service.createProfile(avatarSeed: avatarSeed, displayName: name);
      if (!mounted) return;
      widget.onComplete(profile);
    } catch (e, stack) {
      debugPrint('Friends setup failed: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = "Something went wrong on our end - mind trying again?";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarSeed = context.watch<AppState>().avatarSeed;
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Friends')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (avatarSeed != null) Center(child: ProfileAvatar(seed: avatarSeed, size: 72)),
            const SizedBox(height: 20),
            Text(
              'Read together, not alone',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              "Add a few friends and gently nudge each other to keep reading. Nothing about what you read is ever shared - just your streak, if you choose to show it.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Text('YOUR NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              autocorrect: false,
              enableSuggestions: false,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'What should we call you?',
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: (avatarSeed == null || _creating) ? null : () => _confirm(avatarSeed),
              child: _creating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.surface),
                    )
                  : const Text("Let's go"),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown once, right after Friends is enabled - explains why we're about
/// to ask for notification permission before the OS dialog (which carries
/// no context of its own) actually appears.
/// A real confirmation moment for sending a friend request - a snackbar
/// disappears too fast and doesn't feel like anything happened; this gives
/// the action the same visual weight as the rest of the Friends flow.
class _RequestSentSheet extends StatelessWidget {
  const _RequestSentSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.primary.withValues(alpha: 0.15)),
              child: Icon(Icons.mark_email_read_rounded, color: colorScheme.primary, size: 28),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Request sent',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            "They'll see it next time they open Wird - once they accept, you'll both show up on each other's leaderboard.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.4, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
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
}

class _NotificationsExplainerSheet extends StatelessWidget {
  const _NotificationsExplainerSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 32, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            "Want a nudge when it matters?",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll only reach out for the things that matter here - a friend request, or a gentle reminder when a friend's already read today. Nothing else, and you can turn it off anytime.",
            style: TextStyle(fontSize: 13.5, height: 1.4, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.onSurface,
              foregroundColor: colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sounds good'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Not now', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
        ],
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
    final code = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _AddFriendSheet(),
    );
    if (code == null || code.trim().isEmpty) return;
    try {
      await widget.service.sendFriendRequestByCode(code);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => const _RequestSentSheet(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ArgumentError ? '${e.message}' : "Couldn't send request")),
      );
    }
  }

  Future<void> _setOnline(bool online) async {
    setState(() => _profile = _profile.copyWith(friendsEnabled: online));
    await widget.service.setOnline(online);
  }

  Future<void> _setVisibility({bool? showStreak, bool? showAyahs, bool? showHasanat}) async {
    setState(() => _profile = _profile.copyWith(showStreak: showStreak, showAyahs: showAyahs, showHasanat: showHasanat));
    await widget.service.setFieldVisibility(showStreak: showStreak, showAyahs: showAyahs, showHasanat: showHasanat);
  }

  Future<void> _openSettings() async {
    final updated = await showModalBottomSheet<FriendProfile>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _FriendsSettingsSheet(
        profile: _profile,
        onOnlineChanged: _setOnline,
        onFieldChanged: _setVisibility,
      ),
    );
    if (updated != null && mounted) setState(() => _profile = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Friends settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _MinimalProfileRow(profile: _profile, onAddFriend: _addFriend),
          const SizedBox(height: 28),
          _RequestsList(service: widget.service),
          const SizedBox(height: 12),
          _Leaderboard(service: widget.service, onAddFriend: _addFriend),
        ],
      ),
    );
  }
}

/// Just enough identity to confirm "this is me" and act (add a friend) -
/// the full profile (avatar, name, editing) already lives on the Profile
/// screen, so this doesn't repeat it.
class _MinimalProfileRow extends StatelessWidget {
  final FriendProfile profile;
  final VoidCallback onAddFriend;

  const _MinimalProfileRow({required this.profile, required this.onAddFriend});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ProfileAvatar(seed: profile.avatarSeed, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            profile.displayName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onAddFriend,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
          label: const Text('Add'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Everything about managing the Friends feature itself - your code,
/// sharing an invite, going online/offline, and per-field visibility -
/// tucked behind the gear icon rather than living on the main Friends
/// screen, which is about friends and the leaderboard, not settings.
class _FriendsSettingsSheet extends StatefulWidget {
  final FriendProfile profile;
  final ValueChanged<bool> onOnlineChanged;
  final void Function({bool? showStreak, bool? showAyahs, bool? showHasanat}) onFieldChanged;

  const _FriendsSettingsSheet({required this.profile, required this.onOnlineChanged, required this.onFieldChanged});

  @override
  State<_FriendsSettingsSheet> createState() => _FriendsSettingsSheetState();
}

class _FriendsSettingsSheetState extends State<_FriendsSettingsSheet> {
  late FriendProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  void _shareInvite() {
    SharePlus.instance.share(
      ShareParams(
        text: "Join me on Wird, a Quran reading app.\n"
            'Download: https://github.com/afnanpvt/wird/releases/latest/download/wird.apk\n'
            "Then add me as a friend using code ${_profile.friendCode}.",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_profile);
      },
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Friends settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YOUR CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(_profile.friendCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      tooltip: 'Share invite',
                      onPressed: _shareInvite,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Online to friends'),
                      subtitle: const Text('Off hides you completely and pauses nudges'),
                      value: _profile.friendsEnabled,
                      onChanged: (v) {
                        setState(() => _profile = _profile.copyWith(friendsEnabled: v));
                        widget.onOnlineChanged(v);
                      },
                    ),
                    if (_profile.friendsEnabled) ...[
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Show streak'),
                        value: _profile.showStreak,
                        onChanged: (v) {
                          setState(() => _profile = _profile.copyWith(showStreak: v));
                          widget.onFieldChanged(showStreak: v);
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Show ayahs read'),
                        value: _profile.showAyahs,
                        onChanged: (v) {
                          setState(() => _profile = _profile.copyWith(showAyahs: v));
                          widget.onFieldChanged(showAyahs: v);
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Show hasanat'),
                        value: _profile.showHasanat,
                        onChanged: (v) {
                          setState(() => _profile = _profile.copyWith(showHasanat: v));
                          widget.onFieldChanged(showHasanat: v);
                        },
                      ),
                    ],
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

class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet();

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add a friend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
          const SizedBox(height: 6),
          Text(
            "Enter the code they shared with you.",
            style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1),
            decoration: InputDecoration(
              hintText: 'WIRD-7F3K2',
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.onSurface,
              foregroundColor: colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  final FriendsService service;
  const _RequestsList({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequest>>(
      stream: service.incomingRequests(),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const [];
        // Nothing pending - this section simply doesn't exist, rather than
        // taking up space to announce its own emptiness.
        if (requests.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                requests.length == 1 ? '1 friend request' : '${requests.length} friend requests',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              for (final request in requests) _RequestRow(service: service, request: request),
            ],
          ),
        );
      },
    );
  }
}

class _RequestRow extends StatelessWidget {
  final FriendsService service;
  final FriendRequest request;

  const _RequestRow({required this.service, required this.request});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          FutureBuilder<FriendProfile?>(
            future: service.getProfile(request.fromUid),
            builder: (context, snapshot) => snapshot.data == null
                ? CircleAvatar(radius: 18, backgroundColor: colorScheme.outlineVariant)
                : ProfileAvatar(seed: snapshot.data!.avatarSeed, size: 36),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.fromDisplayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('wants to add you', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            color: colorScheme.onSurfaceVariant,
            onPressed: () async {
              try {
                await service.declineFriendRequest(request.fromUid);
              } catch (e, stack) {
                debugPrint('Decline friend request failed: $e\n$stack');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded),
            color: colorScheme.primary,
            onPressed: () async {
              try {
                await service.acceptFriendRequest(request.fromUid);
              } catch (e, stack) {
                debugPrint('Accept friend request failed: $e\n$stack');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Couldn't accept - try again")),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  final FriendsService service;
  final VoidCallback onAddFriend;
  const _Leaderboard({required this.service, required this.onAddFriend});

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
    return StreamBuilder<List<String>>(
      stream: service.friendUids(),
      builder: (context, friendsSnapshot) {
        final friendUids = friendsSnapshot.data ?? const [];
        if (friendUids.isEmpty) {
          return FutureBuilder<FriendProfile?>(
            future: service.getOwnProfile(),
            builder: (context, ownProfile) => _EmptyLeaderboard(
              friendCode: ownProfile.data?.friendCode,
              onAddFriend: onAddFriend,
            ),
          );
        }
        return FutureBuilder<List<LeaderboardEntry>>(
          future: _load(friendUids),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()));
            }
            final entries = snapshot.data!;
            if (entries.isEmpty) {
              return FutureBuilder<FriendProfile?>(
                future: service.getOwnProfile(),
                builder: (context, ownProfile) => _EmptyLeaderboard(
                  friendCode: ownProfile.data?.friendCode,
                  onAddFriend: onAddFriend,
                ),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < entries.length; i++) _LeaderboardRow(rank: i + 1, entry: entries[i]),
              ],
            );
          },
        );
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  const _LeaderboardRow({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _RankBadge(rank: rank),
          const SizedBox(width: 10),
          ProfileAvatar(seed: entry.avatarSeed, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(entry.displayName, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          ),
          _StatColumn(icon: Icons.local_fire_department_rounded, value: entry.streak, label: 'streak'),
          const SizedBox(width: 14),
          _StatColumn(icon: Icons.menu_book_rounded, value: entry.ayahsThisWeek, label: 'ayahs'),
          const SizedBox(width: 14),
          _StatColumn(icon: Icons.auto_awesome_rounded, value: entry.hasanatThisWeek, label: 'hasanat'),
        ],
      ),
    );
  }
}

/// Drawn rank indicator - a tinted circle with a trophy glyph for the top
/// 3, a plain number otherwise. Deliberately not emoji medals: those
/// render as a different picture on every OS/keyboard skin, which reads as
/// inconsistent rather than polished.
class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  static const _tints = {
    1: Color(0xFFD4AF37), // gold
    2: Color(0xFFA8A9AD), // silver
    3: Color(0xFFB08D57), // bronze
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tint = _tints[rank];
    return SizedBox(
      width: 28,
      height: 28,
      child: tint == null
          ? Center(
              child: Text(
                '$rank',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colorScheme.onSurfaceVariant),
              ),
            )
          : Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: tint.withValues(alpha: 0.18)),
              child: Icon(Icons.emoji_events_rounded, size: 16, color: tint),
            ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final int? value;
  final String label;
  const _StatColumn({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(height: 2),
        Text(
          value == null ? '-' : '$value',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: value == null ? colorScheme.onSurfaceVariant : colorScheme.onSurface),
        ),
      ],
    );
  }
}

/// Shown the first time someone has zero friends - a warm, one-time
/// explanation of what to do next rather than a bare "no friends" label.
class _EmptyLeaderboard extends StatelessWidget {
  final String? friendCode;
  final VoidCallback onAddFriend;
  const _EmptyLeaderboard({required this.friendCode, required this.onAddFriend});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 40, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'No friends yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            friendCode == null
                ? "Add someone as a friend to see how you're both doing."
                : "Add someone as a friend, or share your code $friendCode with them so they can add you.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.4, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.tonal(onPressed: onAddFriend, child: const Text('Add a friend')),
        ],
      ),
    );
  }
}
