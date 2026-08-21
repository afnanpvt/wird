# wird

![wird - build a lasting relationship with the quran](docs/hero.webp)

a quran reading app for one person: whoever's holding the phone.

## what is this

wird (ورد) is the arabic word for a person's regular, committed portion of quran recitation. the daily habit you keep, not the one you meant to start someday. that's the whole idea here: read a little, every day, and have something honest keep track of it for you.

it's a habit tracker wearing a quran app's clothes, or maybe the other way around. either way, there's no leaderboard, no notifications guilting you at 9pm, and nobody but you will ever see your streak.

## why build another quran app

because there are already a bunch of good ones, and this isn't trying to replace them. it's trying to be *mine*. i wanted a streak mechanic that didn't feel like it was designed to make me anxious, translations i could actually understand without a footnote, and a reading screen that doesn't make me feel like i'm filling out a form.

if this feels inspired by the gamified habit apps you already know, it is. i just wanted that energy pointed at something that actually matters to me.

## get it

**[↓ download the apk](https://github.com/afnanpvt/wird/releases/latest/download/wird-1.6.0.apk)**
tap it, it downloads right away, no page in between.

**or, for auto-updates: f-droid**
add `https://afnanpvt.github.io/wird/repo` as a custom repo in the [f-droid client](https://f-droid.org/), then install wird from there. it's a self-hosted repo rather than the main f-droid index, so you're trusting this project's own signing key instead of f-droid's review process - same tradeoff as any indie repo.

either way android will warn you about installing from outside the play store. expected for an app that isn't on the play store, not a sign anything's wrong. every release is signed with the same key, so updates stay clean whichever way you installed.

## what's new in 1.6.0

- **listen to a whole surah**, not just one verse at a time: tap the play icon next to any surah in browse to start continuous recitation, ayah after ayah, that keeps playing in the background with real lock-screen and notification controls
- **four reciters** to choose from in settings: yasser al-dosari (now the default), abdul rahman al-sudais, mahmoud khalil al-husary, and abdul basit. mishary alafasy has been retired
- browse's surah and juz tabs now point at each other: every surah shows which juz it falls in, every juz shows which surah it starts in, and tapping the juz label while reading jumps straight to that juz's start
- a persistent bottom bar (home, browse, bookmarks, settings) replaces the old scroll-down-and-tap navigation
- fixed uneven spacing in browse's surah list

and from 1.5.0: recitation audio for a single verse (the feature the above builds on), a fixed session timer that was opening already showing hours of your all-time total, a streak calendar that no longer bobs between months, and an end-of-session summary that matches the home screen's stat styling.

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
- search across surah, juz, and your saved verses from browse
- a short first-time setup: your name (optional), pick a script, that's it, no accounts
- a quiet first-run tour pointing at the three things worth knowing, shown once
- a small celebration when you finish a surah or a juz, nothing that gets in the way of actually reading
- lets you jump into any surah or juz without messing up where you were actually reading
- keeps a running total of time spent reading, across every session, forever
- remembers exactly where you left off and gets you back there in one tap

## your data stays on your phone

everything wird tracks, your streak, your progress, your reading position, lives in local storage on your device and nowhere else. no account, no login, no server, no cloud sync. i'm not interested in your data and i built it so i couldn't have it even if i wanted to.

that also means: if you uninstall the app, it's gone. there's no cloud backup to restore from. that's the tradeoff for genuinely not collecting anything.

one honest exception as of 1.5.0: tapping play streams that recitation from everyayah.com, whether it's a single verse or a whole surah playing in the background. that's a request for public audio, not anything about you, and it only happens when you tap play, nothing loads or calls out on its own. it's also the only thing in this app that needs internet access at all.

## contributing

purposeful contributions are welcome. bug fixes, better translations, accessibility improvements, cleaner code, all of it.

a couple of things worth knowing before you open a pr: this project handles quranic text, so accuracy matters more than usual. if you're touching anything related to the arabic text, translations, or how verses are numbered, please double-check your sources and say what you checked. and since this is meant to stay a calm, quiet app, features that add noise, tracking, ads, or anything that isn't in service of someone actually reading more consistently probably aren't the right fit here.

open an issue first if you're planning something big, so we're not duplicating effort.

## feedback or issues

afnan.wird@gmail.com, or open an issue here on github. either works.

## a note on why this exists

no pressure, no guilt, no cloud. just you and a book that's been read the same way for fourteen hundred years, tracked by an app that minds its own business.
