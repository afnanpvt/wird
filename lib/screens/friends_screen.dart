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
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
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
              shape: const StadiumBorder(),
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
              shape: const StadiumBorder(),
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
            icon: const Icon(Icons.settings_rounded),
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
                      icon: const Icon(Icons.share_rounded),
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
              // Every code starts with the fixed "WIRD-" prefix - showing it
              // as a static label rather than making someone type it every
              // time (they only ever enter the 5-character suffix).
              prefixText: 'WIRD-',
              prefixStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1, color: colorScheme.onSurfaceVariant),
              hintText: '7F3K2',
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onSubmitted: (value) => Navigator.of(context).pop('WIRD-$value'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.onSurface,
              foregroundColor: colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(context).pop('WIRD-${_controller.text}'),
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
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                Text('wants to add you', style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_rounded),
            color: colorScheme.onSurfaceVariant,
            onPressed: () async {
              try {
                await service.declineFriendRequest(request.fromUid);
              } catch (e, stack) {
                debugPrint('Decline friend request failed: $e\n$stack');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Couldn't decline - try again")),
                );
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

enum _Rank { streak, ayahs, hasanat }

extension on _Rank {
  String get label => switch (this) { _Rank.streak => 'Streak', _Rank.ayahs => 'Ayahs', _Rank.hasanat => 'Hasanat' };
  String get unit => switch (this) { _Rank.streak => 'day streak', _Rank.ayahs => 'ayahs this week', _Rank.hasanat => 'hasanat this week' };
  IconData get icon => switch (this) {
        _Rank.streak => Icons.local_fire_department_rounded,
        _Rank.ayahs => Icons.menu_book_rounded,
        _Rank.hasanat => Icons.auto_awesome_rounded,
      };
  int? valueOf(LeaderboardEntry e) => switch (this) {
        _Rank.streak => e.streak,
        _Rank.ayahs => e.ayahsThisWeek,
        _Rank.hasanat => e.hasanatThisWeek,
      };
}

/// The group's standings: pick what to rank by (streak, ayahs or hasanat
/// this week), see where you stand and how far the next spot is, and who
/// has read today. Friends who hide a stat sort below everyone who shares it.
class _Leaderboard extends StatefulWidget {
  final FriendsService service;
  final VoidCallback onAddFriend;
  const _Leaderboard({required this.service, required this.onAddFriend});

  @override
  State<_Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<_Leaderboard> {
  _Rank _rank = _Rank.streak;
  Future<List<LeaderboardEntry>>? _future;
  String _futureKey = '';

  Future<List<LeaderboardEntry>> _load(List<String> friendUids) async {
    final entries = <LeaderboardEntry>[];
    final ownProfile = await widget.service.getOwnProfile();
    if (ownProfile != null) {
      final ownStats = await widget.service.getStats(ownProfile.uid);
      entries.add(LeaderboardEntry.forSelf(ownProfile, ownStats));
    }
    for (final uid in friendUids) {
      try {
        final profile = await widget.service.getProfile(uid);
        if (profile == null || !profile.friendsEnabled) continue;
        final stats = await widget.service.getStats(uid);
        entries.add(LeaderboardEntry.from(profile, stats));
      } catch (_) {
        // One unreachable friend shouldn't blank the whole board.
      }
    }
    return entries;
  }

  List<LeaderboardEntry> _sorted(List<LeaderboardEntry> entries) {
    final sorted = [...entries];
    sorted.sort((a, b) {
      final primary = (_rank.valueOf(b) ?? -1).compareTo(_rank.valueOf(a) ?? -1);
      if (primary != 0) return primary;
      return (b.hasanatThisWeek ?? -1).compareTo(a.hasanatThisWeek ?? -1);
    });
    return sorted;
  }

  Widget _empty() => FutureBuilder<FriendProfile?>(
        future: widget.service.getOwnProfile(),
        builder: (context, own) => _EmptyLeaderboard(friendCode: own.data?.friendCode, onAddFriend: widget.onAddFriend),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: widget.service.friendUids(),
      builder: (context, friendsSnapshot) {
        final friendUids = friendsSnapshot.data ?? const [];
        if (friendUids.isEmpty) return _empty();
        // Cached per friend list: switching the ranking metric re-sorts
        // locally instead of re-fetching every friend from Firestore.
        final key = friendUids.join(',');
        if (key != _futureKey) {
          _futureKey = key;
          _future = _load(friendUids);
        }
        return FutureBuilder<List<LeaderboardEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(
                  child: TextButton(
                    onPressed: () => setState(() => _futureKey = ''),
                    child: const Text("Couldn't load friends. Tap to retry"),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()));
            }
            final entries = _sorted(snapshot.data!);
            if (entries.length <= 1) return _empty();
            final myIndex = entries.indexWhere((e) => e.isSelf);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (myIndex >= 0) _StandingCard(rank: _rank, entries: entries, myIndex: myIndex),
                const SizedBox(height: 16),
                SegmentedButton<_Rank>(
                  showSelectedIcon: false,
                  segments: [for (final r in _Rank.values) ButtonSegment(value: r, label: Text(r.label), icon: Icon(r.icon, size: 16))],
                  selected: {_rank},
                  onSelectionChanged: (s) => setState(() => _rank = s.first),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < entries.length; i++) _LeaderboardRow(rank: i + 1, entry: entries[i], metric: _rank),
              ],
            );
          },
        );
      },
    );
  }
}

/// Headline for the board: your place and the exact gap to the next one up
/// (or the lead you're holding) - real numbers only.
class _StandingCard extends StatelessWidget {
  final _Rank rank;
  final List<LeaderboardEntry> entries;
  final int myIndex;
  const _StandingCard({required this.rank, required this.entries, required this.myIndex});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final me = entries[myIndex];
    final mine = rank.valueOf(me) ?? 0;
    final readCount = entries.where((e) => e.readToday).length;

    final String detail;
    if (myIndex == 0) {
      final next = rank.valueOf(entries[1]);
      detail = next == null ? "You're leading." : "You're leading by ${mine - next}.";
    } else {
      final above = entries[myIndex - 1];
      final aboveValue = rank.valueOf(above);
      detail = aboveValue == null ? '${above.displayName} is next up.' : '${aboveValue - mine} behind ${above.displayName}.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.primary.withValues(alpha: 0.14)),
            child: Text(
              '#${myIndex + 1}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colorScheme.primary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$mine ${rank.unit}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  '$readCount of ${entries.length} read today',
                  style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final _Rank metric;
  const _LeaderboardRow({required this.rank, required this.entry, required this.metric});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final others = [for (final r in _Rank.values) if (r != metric) r];
    final value = metric.valueOf(entry);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: entry.isSelf ? colorScheme.primary.withValues(alpha: 0.1) : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: entry.isSelf ? Border.all(color: colorScheme.primary.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        children: [
          _RankBadge(rank: rank),
          const SizedBox(width: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              ProfileAvatar(seed: entry.avatarSeed, size: 40),
              if (entry.readToday)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary,
                      border: Border.all(color: colorScheme.surface, width: 2),
                    ),
                    child: Icon(Icons.check_rounded, size: 10, color: colorScheme.onPrimary),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isSelf ? '${entry.displayName} (you)' : entry.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [for (final r in others) '${r.valueOf(entry) ?? '-'} ${r.label.toLowerCase()}'].join('  ·  '),
                  style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value == null ? '-' : '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: value == null ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
            ),
          ),
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
