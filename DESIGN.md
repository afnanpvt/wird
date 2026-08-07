# Design

## Palette (dark — default)

- Background: `#0A0908` (near-black, warm-tinted)
- Surface (elevated content, e.g. ayah panels): `#171512`
- Ink (primary text): `#F5F1EA`
- Muted (secondary text/labels): `#8F857A`
- Accent (flame orange): `#FF7A45` — streak numeral, active states, a couple of link-style accents only
- Divider/outline: `#2A2621`

## Palette (light — available via Settings toggle)

- Background: `#FAF7F2`, Surface: `#F3EEE6`, Ink: `#2B2622`, Muted: `#6B6259`, Accent: `#A8562E`, Divider: `#E3DCD0`

Both themes are fully supported and user-switchable (Settings → Appearance: System/Light/Dark). Rationale: dark, high-contrast, Apple Fitness/Health energy rather than a quiet cream utility-app look. Avoids the expected green-and-gold "Islamic app" palette cliché in favor of a warm ember accent.

## Buttons: monochrome, not accent-colored

All solid/outlined/filled buttons (primary CTAs, nav arrows, "I'm done") are **monochrome**: black-on-light-background in light mode, white-on-dark-background in dark mode (`colorScheme.onSurface` as the fill, `colorScheme.surface` as the foreground). The accent color is reserved for the streak numeral, the streak-fire glyph, and small text-link-style affordances ("Show more") — never for button fills. This was an explicit correction after an earlier pass used the accent color on buttons.

## Typography

- UI family: **Inter** (400/500/600/700). One family carries headings, labels, body, buttons.
- Quran Arabic family: user-selectable, three genuinely distinct script families (`lib/models/quran_script.dart` is the single source of truth for the font/text/spacing pairing per script — add new scripts there, not by hardcoding font names in screens):
  - **Indo-Pak Nastaleeq** (`QuranNastaleeq` → AlQuran IndoPak by QuranWBW v4.2.1-WL) — the diagonal cursive script used in South Asian Mushafs. This is the *matched pair* for the QUL `indopak-nastaleeq` text this app ships, and is what Quran.com serves in production. NOT FOSS-licensed and its license asks for written notice before distribution — see `assets/fonts/AlQuranIndoPakWBW-ATTRIBUTION.txt`; tag `NonFreeAssets` if shipping via F-Droid.
  - **Uthmani Naskh** (`AmiriQuran` → Amiri Quran, OFL 1.1, github.com/aliftype/amiri) — the upright script used in most Mushafs worldwide, paired with Tanzil's Uthmani text (CC-BY 3.0, see `assets/fonts/Amiri-ATTRIBUTION.txt`).
  - **Uthmani Tajweed** (`AmiriQuranColored` → same Amiri release, tajweed-colored variant) — same Uthmani text, recitation rules color-coded by the font itself.

  This font went through several rounds of back-and-forth before landing here, worth recording so it isn't repeated:

  1. An earlier version of this app used KFGQPC Nastaleeq-Full and hit real mark-collision bugs (small superscript letters overlapping base diacritics), which was mistakenly diagnosed as "mobile text stacks can't shape Nastaleeq" and worked around by downgrading to generic Noto Naskh Arabic. That diagnosis was wrong: Flutter bundles its own HarfBuzz and shapes identically on every platform, so there was no engine limitation to route around. The actual bug was in the font file — KFGQPC Nastaleeq (the `-Full` merged variant specifically) misclassifies several combining marks (U+0614, U+0615, U+0617, U+06D6, U+06ED) as GDEF *base* glyphs instead of *mark* glyphs, so HarfBuzz never attaches them via `mark`/`mkmk` lookups. Verified via direct GDEF/GPOS inspection (fontTools), not just glyph-coverage checks.
  2. Switched to "AlQuran IndoPak by QuranWBW", which had correct GDEF classification (no collisions) but drew U+06E1 — the mark used ~62,000 times as the primary Indo-Pak "jazm"/no-vowel marker — as a plain closed circle instead of the authentic open hook shape. Coverage/collision checks don't catch this; only rendering the actual glyph and comparing against a reference does (embed via `@font-face`/data-URI in a throwaway HTML page, render the suspect codepoint in isolation).
  3. Switched to PDMS Saleem, the only one of four candidates tested that got both GDEF classification and the U+06E1 artwork right. This is where the mark-shape problems ended — but PDMS draws the Lam-Alif ligature (`لا`) as a tight, overlapping hook, which read as wrong/unfamiliar against real printed Indo-Pak Mushafs.
  4. Tried switching to plain **KFGQPC Nastaleeq Regular** (not the `-Full` merged variant that caused step 1's bug) for its more open Lam-Alif hook — legally fine to bundle unmodified, but it reintroduces the same five-mark GDEF misclassification from step 1. Reverted almost immediately: those "misclassified marks" aren't a subtle diacritic overlap, one of them (U+0615, ~3500 occurrences) renders as a large solid circle sitting inline mid-word, visibly breaking words apart (e.g. `رَيْبَ` in 2:2). That severity wasn't visible in the coverage/GDEF numbers — only in rendering real ayahs. **Do not re-attempt this switch without re-checking that specific rendering first.**
  5. Went **back to AlQuran IndoPak by QuranWBW** (step 2's font), now at v4.2.1-WL — and this is the current, settled choice. Step 2's rejection reason had silently expired: it was rejected for drawing U+06E1 as a closed circle across ~62,000 occurrences, but that count was measured against the *old* text source. After the text was re-sourced to QUL's IndoPak Hanafi dataset (see below), U+06E1 occurs only **26** times in the entire Quran — the text uses U+0652 (standard sukun) 62,360 times instead. Re-verified from scratch against the actually-bundled text: **0 missing codepoints** of the 71 used, and **all** marks correctly GDEF-classified (class 3), including the five that KFGQPC gets wrong. Confirmed by rendering real ayahs (2:2, 3:144, 7:17, 6:133) — no circles, no collisions. This is also the font Quran.com serves in production, and the matched pair for our text.

  Lesson worth keeping: a font rejection can be invalidated by a later *text* change. Font and text are one decision, not two — re-measure the font when the text source changes, and vice versa.

  Do not pair the Indo-Pak font with the old `fawazahmed0/quran-api` Indo-Pak text — it uses 13 codepoints (notably U+0658) that these fonts don't cover, which forces font fallback. Font and text must come from the same lineage (QUL/quran.com).

  The Arabic text itself (`assets/data/quran_ar_indopak.json`) was re-sourced from QUL's word-by-word IndoPak Hanafi dataset, which uses more correct Indo-Pak orthographic conventions than the previous source: U+0670 (superscript alef) instead of a plain fatha, U+06CC (Farsi Yeh) instead of standard Yeh, U+0652 (standard sukun) instead of U+06E1 in some positions. This does NOT change any letterform shape with this font (verified by rendering the same word both ways — byte-identical), it's purely a textual-accuracy improvement. That dataset also embeds ~300 Private-Use-Area codepoints per-ayah for QuranWBW's proprietary decorative ayah-end ornaments (a different PUA codepoint per ayah number, e.g. U+F500 = ayah-ending-1, appearing once per surah) — these only resolve to a glyph in QuranWBW's own font and were stripped during import; the app doesn't render ayah-end ornaments inline in the text anyway.

  Word spacing for dense Nastaleeq is done via `_SpacedArabicText` (a `Wrap` of per-word `Text` widgets with real gaps), NOT `TextStyle.letterSpacing`/`wordSpacing` — both are confirmed no-ops for RTL/complex-script text on this Flutter engine ([flutter/flutter#177406](https://github.com/flutter/flutter/issues/177406), [#124480](https://github.com/flutter/flutter/issues/124480)). Verified empirically: setting `letterSpacing` to 1.5, 4, then 20 on the same ayah produced byte-identical screenshots each time. Splitting on whitespace is safe here — marks only ever attach within a word, never across a word boundary, so each word stays one shaped HarfBuzz run and the per-ayah-cluster rule above is untouched.

  Legibility inside a word (distinguishing individual joined letters) is NOT a spacing problem and has no spacing fix. PDMS Saleem's letters connect via GPOS `curs` (cursive attachment anchors), confirmed via fontTools — adjacent letters snap to anchor points regardless of any advance-width padding, so the same class of trick that fixed word-spacing does nothing here. The only lever that changes anything without breaking the joined-cursive look is raw size: ayah text is 42 (up from 32), bismillah 27 (up from 22) — bigger glyphs give the eye more room to trace each letter while keeping the authentic connected forms. Disabling `curs` would produce visible letter-to-letter gaps but renders every letter in its isolated form, which is not Nastaleeq anymore — ruled out.
- Bold, confident numerals for the streak count (Inter ExtraBold, tight negative letter-spacing) — the hero element of the home screen.
- Arabic ayah text sized independently (larger, generous line-height ~2.0–2.2 to give stacked Nastaleeq marks room) since it is content, not UI chrome. No `fontFamilyFallback`, no `letterSpacing`/`wordSpacing` on Quran text — both interfere with mark positioning.

## Layout

- No boxed "cards" for simple stat numbers — plain typographic blocks separated by whitespace and hairline dividers.
- Cards reserved for genuinely distinct content blocks: the Arabic/English ayah panels, the "Continue Reading" goal card, the verse-of-the-day block (expandable via "Show more" instead of hard-truncating).
- Ayah content is vertically centered within the available reading area (not pinned to the top) so short ayahs land at a comfortable eye-line instead of requiring the user to look up the screen; long ayahs still scroll normally from the top.
- No nested cards anywhere.

## Motion

- 150–250ms ease-out on standard transitions and taps.
- Auto-advancing into a new surah uses a horizontal slide matching the reading PageView's own swipe motion, not the platform's default page-route transition — keeps continuous reading feeling continuous across a surah boundary.

## Components

- Primary action: filled monochrome button, 16px radius (30px/stadium for the "I'm done" pill).
- Secondary action: outlined, ink-colored border.
- Stat blocks: number (Inter SemiBold) + muted label beneath, no background fill.
- Ayah panel: surface-color rounded block (24px radius), no shadow, hairline border on the translation panel only.
- Reading-screen header: Juz progress (verses left + percent bar) and two small stat chips (ayahs read this session, lifetime reading-time timer that pauses when the app is backgrounded).
- Translation toggle: a small, non-distracting text link ("I don't understand" / "Show original translation") beneath the translation panel, switching between Saheeh International and The Clear Quran (Khattab) — the choice persists across ayahs and surahs until switched back.
- Home "Continue Reading" card: shows the exact surah + ayah position that will be resumed, with a black/white pill "Read more" button — not a generic unlabeled CTA.
