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

**[↓ download the apk](https://github.com/afnanpvt/wird/releases/latest/download/wird-1.3.1.apk)**
tap it, it downloads right away, no page in between.

**or, for auto-updates: f-droid**
add `https://afnanpvt.github.io/wird/repo` as a custom repo in the [f-droid client](https://f-droid.org/), then install wird from there. it's a self-hosted repo rather than the main f-droid index, so you're trusting this project's own signing key instead of f-droid's review process - same tradeoff as any indie repo.

either way android will warn you about installing from outside the play store. expected for an app that isn't on the play store, not a sign anything's wrong. every release is signed with the same key, so updates stay clean whichever way you installed.

## what's new in 1.3.1

- **corrected the indo-pak arabic text.** the tajweed marks that guide pronunciation, including the iqlab (the small meem written over a nun before a ba), are now all present and verified against the king fahd complex mushaf. if you recite from this app, this one matters.
- stats you can swipe through - today, this week, or all time, each showing ayahs read and time spent reading
- a friday suggestion to read surah al-kahf, in place of the verse of the day
- a warmer, randomized greeting each time you open the app
- a reworded "save as continue reading" prompt, and a handful of small polish fixes throughout

## what it actually does

- reads the quran in three different scripts, indo-pak nastaleeq, uthmani naskh, and uthmani with tajweed color-coding, switchable anytime, each paired with a properly-sourced font and text so the actual letterforms and marks render correctly, not just "close enough"
- arabic text alongside two english translations (saheeh international, and the clear quran for when the literal translation isn't clicking)
- tracks a daily streak with a grace day built in, because missing one day shouldn't erase everything you built
- honest stats only, swipeable by today/this week/all time: ayahs read, time spent reading, best streak. no invented "% of quran read" number, because the app genuinely doesn't know your reading history from before you installed it, and pretending otherwise felt dishonest
- suggests surah al-kahf on fridays, in place of the verse of the day, without touching your saved progress
- a short first-time setup: your name (optional), pick a script, that's it, no accounts
- a quiet first-run tour pointing at the three things worth knowing, shown once
- a small celebration when you finish a surah or a juz, nothing that gets in the way of actually reading
- lets you jump into any surah or juz without messing up where you were actually reading
- keeps a running total of time spent reading, across every session, forever
- remembers exactly where you left off and gets you back there in one tap

## your data stays on your phone

everything wird tracks, your streak, your progress, your reading position, lives in local storage on your device and nowhere else. no account, no login, no server, no cloud sync. i'm not interested in your data and i built it so i couldn't have it even if i wanted to.

that also means: if you uninstall the app, it's gone. there's no cloud backup to restore from. that's the tradeoff for genuinely not collecting anything.

## contributing

purposeful contributions are welcome. bug fixes, better translations, accessibility improvements, cleaner code, all of it.

a couple of things worth knowing before you open a pr: this project handles quranic text, so accuracy matters more than usual. if you're touching anything related to the arabic text, translations, or how verses are numbered, please double-check your sources and say what you checked. and since this is meant to stay a calm, quiet app, features that add noise, tracking, ads, or anything that isn't in service of someone actually reading more consistently probably aren't the right fit here.

open an issue first if you're planning something big, so we're not duplicating effort.

## feedback or issues

afnan.wird@gmail.com, or open an issue here on github. either works.

## a note on why this exists

no pressure, no guilt, no cloud. just you and a book that's been read the same way for fourteen hundred years, tracked by an app that minds its own business.
