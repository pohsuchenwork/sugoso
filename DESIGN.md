# Design Brief - Sugoso

The single source of truth for the visual system. Tokens live in
`Sources/SugosoCore/Theme.swift`; this document is the *why*.

## What this product is
A macOS **menu-bar focus timer** (the Pomodoro technique) with a lightweight task
list. It lives in the menu bar and is used in **short glances** across a workday:
start a focus sprint, take a break, see what to work on next. It is not a
dashboard, not gamified, not a "productivity suite."

**User:** someone mid-work who wants gentle structure (focus / rest rhythm)
without a heavy app stealing attention.

**Register:** *calm, focused, native.* It should be quiet when idle, reassuring at
a glance, and feel like it ships with macOS - precise (it is a clock) but warm
(it is about human rhythms of work and rest).

## Category research (focus timers & calm macOS apps)
- **Session (macOS):** extremely restrained - neutral palette, system type, a big
  calm timer, almost no chrome. Reads as native and quiet.
- **pomofocus.io:** **color encodes state** - the UI shifts hue between focus
  (warm red) and break (cool teal). Clean task rows with estimate/actual counts.
- **Things 3:** the calm-macOS benchmark - generous whitespace, *one* restrained
  accent, impeccable type rhythm, zero decoration.
- **Forest:** a single strong identity concept (a tree); warm, but playful/mobile.
- **Be Focused / Flow:** menu-bar timers; minimal, system-native, color used only
  for the running state.

**Takeaways:** (1) lean native - system font & materials; (2) let **color encode
focus-vs-break state**, not decorate; (3) whitespace + type over chrome; (4) keep
one strong identity element.

## The brief (locked)
- **Personality:** calm · focused · native.
- **Dominant:** neutral. The native popover material + system label colors
  (`.primary`/`.secondary`/`.tertiary`, auto light/dark). The app is mostly quiet.
- **Accent - state-driven, never two at once:**
  - **Focus → Terracotta** (a muted tomato red; the tomato identity).
  - **Break → Sage** (a calm muted green; restful).
  These are mutually-exclusive *status* colors. Color tells you which mode you are
  in - functional, not decorative.
- **Type (2 families, both native):**
  - **SF Pro Rounded** - timer numerals & key counts (friendly, clock-like).
  - **SF Pro** - all UI text (native, legible).
- **Spacing:** 4-pt base → 4 / 8 / 12 / 16 / 24.
- **Radii:** 6 / 10 / 14.
- **Icons:** **SF Symbols** - Apple's native icon system (the macOS equivalent of
  Lucide/Phosphor), one consistent weight & size.

## Deliberate deviation (flagged)
The **tomato** glyph is retained as the product's single brand/session mark. It is
the namesake of the Pomodoro technique and an explicit, repeated product-owner
preference, so it reads as *identity*, not as a generic emoji-as-icon tell. Every
**functional** icon uses SF Symbols; the tomato/coffee/palm glyphs are used only
as the session-type identity. This is the one knowing exception to "no emoji icons."

## Tokens → `Theme.swift`
`Theme.Spacing`, `Theme.Radius`, `Theme.Palette` (focus/break, light+dark),
`Theme.accent(for:)` (state color), `Theme.Typo` (timer/counter/title/body/label).
No raw hex or magic spacing in the views.
