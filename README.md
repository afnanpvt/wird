# wird

![wird - build a lasting relationship with the quran](docs/hero.webp)

a quran reading app for one person: whoever's holding the phone.

## what is this

wird (ورد) is the arabic word for a person's regular, committed portion of quran recitation. the daily habit you keep, not the one you meant to start someday. that's the whole idea here: read a little, every day, and have something honest keep track of it for you.

it's a habit tracker wearing a quran app's clothes, or maybe the other way around. by default there's no leaderboard, no notifications guilting you at 9pm, and nobody but you will ever see your streak. as of 1.9.0 there's an entirely optional friends feature if you want a little accountability, see "the friends feature" below - and as of 1.12.0, an entirely optional way to back up your progress with a Google sign-in, off unless you turn it on.

## why build another quran app

because there are already a bunch of good ones, and this isn't trying to replace them. it's trying to be *mine*. i wanted a streak mechanic that didn't feel like it was designed to make me anxious, translations i could actually understand without a footnote, and a reading screen that doesn't make me feel like i'm filling out a form.

if this feels inspired by the gamified habit apps you already know, it is. i just wanted that energy pointed at something that actually matters to me.

## get it

**[↓ download the apk](https://github.com/afnanpvt/wird/releases/latest/download/wird.apk)**
tap it, it downloads right away, no page in between.

**or, for auto-updates: f-droid**
add `https://afnanpvt.github.io/wird/repo` as a custom repo in the [f-droid client](https://f-droid.org/), then install wird from there. it's a self-hosted repo rather than the main f-droid index, so you're trusting this project's own signing key instead of f-droid's review process - same tradeoff as any indie repo.

either way android will warn you about installing from outside the play store. expected for an app that isn't on the play store, not a sign anything's wrong. every release is signed with the same key, so updates stay clean whichever way you installed.

## what's new in 1.12.1

- fixed Google Sign-In failing on the real published app (worked fine in testing) - the app was quietly initializing Firebase with the wrong internal identity in the public build ever since Friends launched, invisible until real Google sign-in actually checked it

and from 1.12.0:

- **optional backup with Google**: sign in with Google (from onboarding, or anytime later from a card on home) to back up your streak, hasanat, day-by-day stats, bookmarks and saved verses, so a reinstall or a new phone can bring them back. entirely opt-in and off by default - never signing in means wird behaves exactly as this readme describes, fully local. never includes which specific ayahs you're reading, and deletable anytime from the same screen. see the in-app privacy policy for the full detail

and from 1.11.0:

- **stats, on the same screen as the calendar**: no more separate stats screen behind a corner icon - scroll down from the reading calendar and it's right there. added your current and longest streak up top, and a few honest trend numbers below the heatmap: best day ever, your average on days you actually read (never divided by days you didn't), this week against last week, and how many of your days since you started have had any reading at all. same rule as always - nothing here is an invented goal or a made-up percentage
- fixed the ayah counter next to hasanat climbing every time you swiped back and forth over the same verses, instead of only counting ones you'd actually newly read

and from 1.10.2:

- fixed hasanat not counting when re-reading verses you've already read before, and occasionally double-counting

and from 1.10.1:

- fixed "I'm done" landing back on a surah you already finished instead of where you actually started, if you'd read through more than one surah in a row

and from 1.10.0:

- **stats by day**: a new screen off the reading calendar showing exactly how much you've read, day by day. switch between ayahs, hasanat, or time as the metric, and between week, month, or year as the view, then tap any day for its full breakdown. honest numbers only, same as everywhere else in wird, no invented percentages or goals

and from 1.9.1:

- the nightly recitation card on home now only shows up in the evening and overnight, since it's meant for that part of the day, not all day

and from 1.9.0:

- **friends, entirely optional**: don't open the friends tab and nothing about you ever leaves your phone, same as before. if you do want it: a friend code to add people you actually know, a small leaderboard of streaks/ayahs/hasanat among just the two (or few) of you, and a nudge when a friend reads. see "the friends feature" below
- **nightly recitation**: a guided sequence through the authentically-established nightly recitations (ayat al-kursi, al-baqarah's last two verses, the three quls, al-kafirun, al-mulk), one step at a time with real progress
- **popular reads on home**: a quiet shelf of commonly-read surahs (yaseen, ar-rahman, al-muzzammil, ayat al-kursi) for a quick one-tap read that doesn't touch your continue-reading spot
- **send feedback**: a proper feedback form from the about screen, straight to the developer
- an app-wide visual pass: consistent button shapes, card corners, spacing, and text sizing throughout, and every dialog replaced with a proper bottom sheet
- fixed the jarring slide-up-then-fade transition between ayahs on the now playing screen, it's a plain cross-fade now

and from 1.7.1: seamless confetti-celebrated surah transitions while listening, ambient artwork glows on the now playing screen, a dedicated listen tab, and richer notification/lock-screen media controls.

## what it actually does

- reads the quran in three different scripts, indo-pak nastaleeq, uthmani naskh, and uthmani with tajweed color-coding, switchable anytime, each paired with a properly-sourced font and text so the actual letterforms and marks render correctly, not just "close enough"
- tap play on any ayah to hear it recited, or tap a surah's play icon in browse to listen straight through it in the background - four reciters to pick from in settings, streamed on demand
- arabic text alongside two english translations (saheeh international, and the clear quran for when the literal translation isn't clicking), plus an optional transliteration line
- as many named bookmarks as you want, one of them set as your home screen default, the rest just sitting there until you resave them
- save any verse with a tap, find it again later under browse's saved tab
- hasanat: a running total of the reward for reciting, counted the traditional way (ten per letter)
- tracks a daily streak with a grace day built in, because missing one day shouldn't erase everything you built, shown as a real calendar you can page through, not just a number
- honest stats only, swipeable by today/this week/all time: ayahs read, time spent reading, best streak. no invented "% of quran read" number, because the app genuinely doesn't know your reading history from before you installed it, and pretending otherwise felt dishonest
- suggests surah al-kahf on fridays, in place of the verse of the day, without touching your saved progress
- a guided nightly recitation, one step at a time through the authentically-established nightly verses, with real progress
- a quiet shelf of commonly-read surahs on the home screen for a quick one-tap read, without touching your continue-reading spot
- search across surah, juz, and your saved verses from browse
- send feedback straight from the about screen, no email client needed
- a short first-time setup: your name (optional), pick a script, that's it, no accounts
- a quiet first-run tour pointing at the three things worth knowing, shown once
- a small celebration when you finish a surah or a juz, nothing that gets in the way of actually reading
- lets you jump into any surah or juz without messing up where you were actually reading
- keeps a running total of time spent reading, across every session, forever
- remembers exactly where you left off and gets you back there in one tap

## your data stays on your phone

everything wird tracks, your streak, your progress, your reading position, lives in local storage on your device and nowhere else. no account, no login, no server, no cloud sync. i'm not interested in your data and i built it so i couldn't have it even if i wanted to.

that also means: if you uninstall the app, it's gone. there's no cloud backup to restore from. that's the tradeoff for genuinely not collecting anything.

one honest exception as of 1.5.0: tapping play streams that recitation from everyayah.com, whether it's a single verse or a whole surah playing in the background. that's a request for public audio, not anything about you, and it only happens when you tap play, nothing loads or calls out on its own.

another one as of 1.9.0: the friends feature, covered fully below.

## the friends feature

entirely opt-in: nothing happens until you open the friends tab yourself and go through setup (pick a name, get a friend code). don't open that tab, and wird behaves exactly like the rest of this readme describes, fully offline.

if you do set it up: you get a friend code to share with people you actually know, a small leaderboard of streaks/ayahs/hasanat between you and whoever you've added, and a nudge when a friend reads. there's no way to browse or discover other users, no public profile, nothing searchable, adding someone requires their code. no private messaging, no real name required (you pick what shows), no location.

## contributing

purposeful contributions are welcome. bug fixes, better translations, accessibility improvements, cleaner code, all of it.

a couple of things worth knowing before you open a pr: this project handles quranic text, so accuracy matters more than usual. if you're touching anything related to the arabic text, translations, or how verses are numbered, please double-check your sources and say what you checked. and since this is meant to stay a calm, quiet app, features that add noise, tracking, ads, or anything that isn't in service of someone actually reading more consistently probably aren't the right fit here.

open an issue first if you're planning something big, so we're not duplicating effort.

## feedback or issues

afnan.wird@gmail.com, or open an issue here on github. either works.

## a note on why this exists

no pressure, no guilt, no cloud. just you and a book that's been read the same way for fourteen hundred years, tracked by an app that minds its own business.
