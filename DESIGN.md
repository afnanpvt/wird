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
- Quran Arabic family: **Noto Naskh Arabic** — same font family Android ships as its native Arabic fallback, so GPOS mark-to-base/mark-to-mark positioning is guaranteed correct. Do not swap to a Nastaleeq-style font: Nastaleeq requires exotic contextual shaping that most mobile text-rendering stacks (including Android's) don't fully implement, causing combining marks to collide with base diacritics instead of stacking cleanly. Naskh fonts don't have this problem. Confirmed full glyph coverage (including the Arabic Extended-A marks this Indo-Pak text needs) via direct cmap inspection before adopting.
- Bold, confident numerals for the streak count (Inter ExtraBold, tight negative letter-spacing) — the hero element of the home screen.
- Arabic ayah text sized independently (larger, generous line-height ~1.9) since it is content, not UI chrome.

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
