# Friends & Social — Design Spec

Date: 2026-09-09
Status: Approved for planning

## Problem

Wird is currently a fully local, offline-first app: Hive for storage, no
accounts, no backend, no networking. There is a desire for an **optional**
social layer where users can:

1. Add friends and see a friends-only leaderboard of reading activity.
2. Get a gentle nudge notification when a friend reads Qur'an, encouraging
   them to read too.

This must be entirely opt-in so the app's core offline experience is
unaffected for anyone who doesn't want it — see *Feature entry point*
below for how opt-in works without a master switch.

## Non-goals

- No public/global leaderboard — friends-only.
- No contacts-based friend discovery (phone number matching) — invite
  code/username only. Contacts-based discovery is an explicitly deferred
  future phase, not part of this design.
- No sharing of *what* was read (surah/ayah content, reading history) with
  friends — only aggregate numbers (streak, ayahs, hasanat).
- No chat/messaging between friends.
- Friends feature does not affect the reading experience, audio playback,
  or any existing offline functionality.

## Why a backend is required

Wird has zero networking dependencies today. A friends feature inherently
needs a place to hold user identities, the friend graph, and to relay
notifications between two different devices that may never be online at
the same time — none of which Hive (local, per-device storage) can do.
This is the single biggest scope change introduced by this feature: Wird
gains its first piece of live infrastructure to build and maintain.

**Chosen platform: Firebase, free "Spark" plan only** (Auth + Firestore).
Rationale: no servers to provision or operate, and the free tier comfortably
covers a small friend-group app — the lowest-maintenance, **zero-cost**
option for a solo/small-team Flutter project with no existing backend.

**Hard constraint: no billing card, ever.** This rules out Cloud Functions
and server-sent push (FCM), both of which require Firebase's pay-as-you-go
"Blaze" plan (Cloud Functions can't deploy on Spark at all; sending FCM
pushes from a trusted sender normally means a server holding a service
account key, which Cloud Functions would host). Two consequences ripple
through this design:

1. **Friend-request accept/friend-list writes happen client-side**,
   enforced by Firestore Security Rules instead of server logic (see
   *Adding friends* below).
2. **No real-time push notifications.** Instead, nudges are delivered via
   a client-side background check + local notification (see *Notification
   flow* below) — not instant, but fully free and serverless.

## Feature entry point (revised — no master on/off)

There is no single "enable Friends" switch. A **"Friends" tab/section is
always present** in the app. The first time a user opens it, a short
one-time setup screen — pick an avatar, done — creates their profile,
username, and friend code. That setup step *is* the opt-in: never opening
the tab means never provisioning any cloud account, so the zero-footprint
default is preserved without needing an explicit switch to express it.

## Profile setup

- **Avatar only, no gallery upload** (explicitly out of scope for this
  phase — see *Why no gallery photos* below). A one-time picker shows a
  grid of **13 predefined avatars** generated via DiceBear's abstract
  "Shapes" style ([dicebear_core](https://pub.dev/packages/dicebear_core) +
  [dicebear_styles](https://pub.dev/packages/dicebear_styles), rendered
  locally as SVGs from 13 fixed seed strings — no network call, no bundled
  image assets). This style draws only abstract geometric shapes on a
  colored background — no human figures, faces, or gendered depictions at
  all, which sidesteps modesty/halal concerns entirely rather than trying
  to curate "appropriate" illustrated people.
- Username is auto-generated (as in the original design); no free-text
  display name input is required to participate.

### Why no gallery photos

Showing an uploaded photo to friends means storing it somewhere friends'
devices can fetch it from — normally Firebase Storage, a second Firebase
product with its own free-tier ceiling, adding a second cost-risk surface
beyond Firestore. Given the hard "$0, no billing card" constraint, gallery
photos are dropped from this phase entirely rather than compromising on a
smaller/base64-in-Firestore workaround. Predefined avatars only.

## Privacy model (revised — no master on/off, no long settings list)

Two concerns, kept deliberately separate and small:

1. **Removing a friend** — a plain per-friend "unfriend" action in the
   friends list (e.g. swipe-to-remove or a menu on their card, with a
   confirmation step). This is just relationship management, not privacy,
   and needs no toggle.
2. **Visibility**, inside the Friends section, exactly **4 switches**,
   clearly labeled, nothing else:
   - **Online/offline** — the one broad switch. Off means invisible to all
     friends and no nudges sent or received, without deleting any cloud
     data (same non-destructive behavior as the original design's
     toggle-off — friend links and stats persist for instantly resuming
     later).
   - **Show streak**, **Show ayahs read**, **Show hasanat** — three
     independent switches controlling which of those three numbers friends
     can see on the leaderboard while online. A hidden field renders as a
     dash for friends viewing it, never a fabricated/zero value.

   This intentionally replaces the original single master toggle: instead
   of one on/off switch, "online/offline" plus 3 field switches is the
   complete privacy surface — 4 items, not 20.

## Data model (Firestore)

```
users/{uid}
  username: string            // generated, e.g. "ahmad_k472"
  friendCode: string          // short shareable code, e.g. "WIRD-7F3K2"
  displayName: string         // from existing SettingsService.getName(), if set
  avatarSeed: string          // one of 13 fixed seeds for DiceBear "Shapes"
  friendsEnabled: bool        // the online/offline switch
  showStreak: bool            // default true
  showAyahs: bool             // default true
  showHasanat: bool           // default true
  createdAt: timestamp

users/{uid}/friends/{friendUid}
  since: timestamp
  // written symmetrically on both users when a request is accepted

friendRequests/{uid}/incoming/{fromUid}
  fromUsername: string
  sentAt: timestamp

stats/{uid}
  currentStreak: int
  longestStreak: int
  ayahsToday: int
  hasanatToday: int
  ayahsThisWeek: int
  hasanatThisWeek: int
  lastSyncedAt: timestamp
  lastActiveDate: string       // yyyy-MM-dd, the day this user last read
```

The 3 `show*` flags live on `users/{uid}`, not `stats/{uid}`, since they're
settings, not activity data — but the leaderboard read path joins both: a
friend's client reads `users/{friendUid}` for the flags and `stats/{uid}`
for the numbers, rendering a dash for any field whose flag is false rather
than fetching/showing the real value at all.

Local-only (Hive, not synced): `notifyThrottle_{friendUid} -> lastNotifiedDateShownLocally`
tracks, per friend, the last date *this device* already showed a nudge for
— see *Notification flow*.

Sync is **one-way, app → cloud**: the device pushes its own `stats/{uid}`
document derived from existing local sources
([`StreakService.getState()`](../../../lib/services/streak_service.dart),
`hasanatToday()/hasanatThisWeek()`, `ayahsReadToday()/ayahsReadThisWeek()`)
after any local update to those values (e.g. right after
`StreakService.recordAyahRead`, and on app resume as a catch-up sync). No
device ever reads another user's raw Hive data or full reading history —
only the aggregate `stats` doc is visible to friends, and it exposes
exactly the three numbers chosen for the leaderboard (streak, ayahs,
hasanat), nothing about specific surahs/ayahs read.

## Adding friends

- Each user's profile screen shows their `friendCode`, shareable via the
  system share sheet (copy link, WhatsApp, etc.).
- Entering someone else's code creates a doc under
  `friendRequests/{targetUid}/incoming/{myUid}`.
- The recipient sees incoming requests and can accept/decline.
- On accept, **the recipient's own client** writes both
  `users/{recipient}/friends/{sender}` and `users/{sender}/friends/{recipient}`
  directly (two writes in one batched Firestore transaction), then deletes
  the request doc. Firestore Security Rules constrain this so a client can
  only ever create a `friends` entry for itself and for the specific UID it
  is accepting a pending request from — a client cannot fabricate arbitrary
  friend links for other users. This replaces the Cloud-Function-mediated
  accept flow with a rules-enforced client write, avoiding any paid
  server-side component.

## Leaderboard

A "Friends" screen lists the user's friends sorted by `currentStreak` desc,
tie-broken by `hasanatThisWeek` desc. Pulled by reading each friend's
`stats/{uid}` doc (a Firestore query across the `friends` subcollection's
UIDs). No pagination needed at expected friend-list sizes.

## Notification flow (no server, no push — client-side detection)

Sender side: the moment `StreakService.recordAyahRead` first flips
"read today" true for the current calendar day, the client syncs its
`stats/{uid}.lastActiveDate` to today (part of the normal stats sync — no
special-cased write).

Receiver side, there is no push — instead, **each friend's own device
detects the update itself**:

1. On app foreground/resume, and via a periodic background task
   (`workmanager` or platform equivalent, e.g. every few hours), the app
   reads `stats/{friendUid}.lastActiveDate` for each friend.
2. For any friend whose `lastActiveDate == today` AND whose
   `notifyThrottle_{friendUid}` (local Hive value) is not already today,
   show a **local notification** via `flutter_local_notifications`:
   > "Ahmad just read Qur'an today — your turn?"
   and set `notifyThrottle_{friendUid}` to today.
3. This enforces **once per friend per day** — the throttle state lives
   per-receiving-device (Hive), not shared/global, since only the receiver
   ever needs to know "have I already nudged myself about this friend
   today."
4. Tapping the notification opens the app to the reading screen.

**Tradeoff, explicit:** this is not instant. A nudge appears the next time
the receiver's app resumes or its periodic background check runs — not
the moment the friend finishes reading. This is the accepted cost of
staying fully serverless and free.

## Staged rollout: dev/prod build flavors

Friends is new, untested, live-infrastructure-backed functionality that
must not reach the public release while it's being validated. Rather than
a runtime remote flag (which would still ship the feature's code and
Firebase wiring inside the public binary, just hidden), this uses a
**compile-time gate** so the public build never contains it at all:

- Two Android Gradle product flavors, `prod` (unchanged `applicationId
  com.afnan.wird`, current app label) and `dev` (`applicationIdSuffix
  ".dev"` → `com.afnan.wird.dev`, labeled "Wird Dev" via a flavor
  `resValue`) — installs as a separate app alongside the public one on the
  same device, rather than replacing it. Implemented in
  [`android/app/build.gradle.kts`](../../../android/app/build.gradle.kts).
- A Dart compile-time flag, `FeatureFlags.friendsEnabled` in
  [`lib/config/feature_flags.dart`](../../../lib/config/feature_flags.dart),
  read from `--dart-define=FRIENDS_ENABLED=true`. All Friends UI entry
  points and Firebase initialization are gated behind this flag.
- Private test builds: `flutter build apk --flavor dev
  --dart-define=FRIENDS_ENABLED=true`, sideloaded directly.
- Public release builds: `flutter build apk --flavor prod` (flag omitted,
  defaults false) — this is what ships to the Play Store, and it never
  compiles the Friends feature's UI into a reachable state.

This scaffolding is already implemented as of this spec revision; the
Friends feature itself is built on top of it.

## New dependencies

- `firebase_core`, `firebase_auth`, `cloud_firestore` only — no
  `cloud_functions`, no `firebase_messaging`.
- `flutter_local_notifications` (local notification display).
- `workmanager` (or equivalent) for periodic background Firestore checks
  when the app isn't foregrounded.
- `dicebear_core` + `dicebear_styles` (local, offline SVG avatar
  generation for the predefined avatar picker — no network call).
- Firebase project setup: `google-services.json` (Android) and Firestore
  Security Rules (no Cloud Functions to write or deploy).

This is new infrastructure Wird does not currently have, but it stays
entirely on Firebase's free Spark plan — no billing card, no servers, no
Cloud Functions to deploy or maintain. The only ongoing maintenance is the
Firebase project itself and its Security Rules.

## Error handling & edge cases

- No network / Firestore unreachable: local reading/streak functionality is
  completely unaffected (sync is fire-and-forget, best-effort; failures are
  silently retried on next app resume, never block or error in the reading
  UI).
- Friend code collisions: generated with enough entropy that collisions are
  practically negligible; on the rare Firestore write conflict, the client
  regenerates and retries.
- User deletes the app / uninstalls: cloud profile and stats persist
  (anonymous Firebase Auth UID tied to device install); no explicit
  account-deletion flow in this phase — noted as a future consideration but
  not required for v1 given anonymous auth has no PII beyond a
  self-chosen display name.

## Testing approach

- Pure logic (throttle-once-per-day check, leaderboard sort/tie-break) unit
  tested the same way `streak_engine.dart`'s pure functions are tested today
  — no Firebase dependency for these.
- Firestore Security Rules tested against the Firebase Local Emulator
  Suite (free, local-only — does not require the Blaze plan).
- Manual UAT: two physical/emulator devices, add each other as friends,
  confirm the background check + local notification fires once per day per
  friend and the leaderboard reflects both streaks.

## Cost summary

Zero cost by design: Firebase Spark (free) plan only — Auth (anonymous,
free/unlimited), Firestore (free tier: ~1.5M reads/~600K writes per month,
far beyond a small friend-group app's usage), no Cloud Functions, no FCM.
No billing card required at any point.
