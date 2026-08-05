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
- Quran Arabic family: **QuranNastaleeq** (AlQuran IndoPak by QuranWBW, based on Al Qalam Quran Majeed, sourced from QUL/Tarteel) — an authentic Indo-Pak Nastaleeq font, paired with matching Indo-Pak text from quran.com's `text_indopak` (via the QUL script data).

  An earlier version of this app used KFGQPC Nastaleeq-Full and hit real mark-collision bugs (small superscript letters overlapping base diacritics), which was mistakenly diagnosed as "mobile text stacks can't shape Nastaleeq" and worked around by downgrading to generic Noto Naskh Arabic. That diagnosis was wrong: Flutter bundles its own HarfBuzz and shapes identically on every platform, so there was no engine limitation to route around. The actual bug was in the font file — KFGQPC Nastaleeq misclassifies several combining marks (U+0614, U+0615, U+0617, U+06D6, U+06ED) as GDEF *base* glyphs instead of *mark* glyphs, so HarfBuzz never attaches them via `mark`/`mkmk` lookups. The `-Full` variant made it worse: merging it with Noto Sans Arabic via fonttools is documented to break `mkmk` entirely. The fix was a font with correct GDEF/GPOS tables, not a different script style — verified via direct GDEF/GPOS inspection (fontTools) before adopting, not just glyph-coverage checks.

  Do not pair this font with the old `fawazahmed0/quran-api` Indo-Pak text — it uses 13 codepoints (notably U+0658) this font doesn't cover, which forces font fallback and reintroduces the same collision. Font and text must come from the same lineage (QUL/quran.com).
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
