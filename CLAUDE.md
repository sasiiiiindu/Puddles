# Puddles

A native macOS **menu bar** app (Swift) that reminds you to drink water. When a
reminder fires, a **pixel-art cat** walks in from the right edge of the screen,
shows a speech bubble ("Time for water! 💧"), waits, then walks off.

## Hard constraint: Swift Package Manager only, no Xcode

This project is built with **SwiftPM and the Command Line Tools only** — assume
no full Xcode / no `.xcodeproj` is available. Everything is driven from
`Package.swift` and `build.sh`. Do not introduce an Xcode project or dependency
on `xcodebuild`.

- `Package.swift` — executable target `Puddles`, macOS 13+, AppKit.
- `build.sh` — runs `swift build -c release`, then assembles `Puddles.app` by
  hand: copies the binary into `Contents/MacOS/`, writes `Info.plist` (with
  `LSUIElement = true` so it's menu-bar-only, no dock icon), and ad-hoc signs.

## Build & run

```bash
# Build (produces ./Puddles.app)
./build.sh

# Launch in the menu bar (droplet icon near the clock; no dock icon)
open Puddles.app

# Watch the overlay animation immediately, without waiting for the timer.
# --demo fires a reminder ~1s after launch. Runs in the foreground so you also
# see NSLog console output.
./Puddles.app/Contents/MacOS/Puddles --demo

# Quit
pkill -x Puddles   # or use the menu's "Quit Puddles" item
```

## Source layout (`Sources/Puddles/`)

- `main.swift` — entry point; `.accessory` activation policy (belt-and-suspenders
  with `LSUIElement`).
- `AppDelegate.swift` — status item + menu ("Remind me now", "Preferences…"
  stub, "Quit"), the repeating reminder timer (default **60 min**), and
  `fireReminder()` which logs and shows the overlay. Honors the `--demo` flag.
- `ReminderOverlayController.swift` — owns one overlay: a borderless,
  transparent, always-on-top, **non-activating** `NSPanel` at the right edge, at
  a random vertical position (avoiding top/bottom ~15%). Choreography: walk in
  (~1.5s ease-out) → pop speech bubble → wait 8s → turn around → walk off
  (~1.5s ease-in) → close. Clicking the cat/bubble dismisses immediately. Only
  one overlay shows at a time.
- `SpriteView.swift` — layer-backed view that cycles sprite frames at **8 fps**,
  drawn at **5× scale with nearest-neighbor** (`interpolationQuality = .none`) so
  pixels stay crisp; flips horizontally to face its walking direction.
- `SpriteSheet.swift` — loads a horizontal PNG sheet and slices it into
  `CGImage` frames. Also `PlaceholderSprite`, which generates a placeholder
  sheet in memory (currently used).
- `SpeechBubbleView.swift` — blocky pixel-style speech bubble (solid-fill
  border, downward tail, monospaced text).

## Current state

- **Phase 1 (done):** menu bar app, `LSUIElement`/accessory (no dock icon),
  menu, repeating reminder timer.
- **Phase 2 (done):** full overlay animation — walk in, speech bubble, idle,
  walk off, close; click-to-dismiss. Sprite pipeline (sheet → slice → cycle →
  5× nearest-neighbor render) works, driven by a **programmatically generated
  placeholder sprite** so it's testable before real art exists.

## What's next

- **Real sprite sheets.** Replace the placeholder with real pixel art:
  - `Resources/walk.png` — **4 frames**, 16×16 each (horizontal sheet, 64×16).
  - `Resources/idle.png` — **2 frames**, 16×16 each (horizontal sheet, 32×16).
  - Load them via the existing `SpriteSheet(pngData:frameCount:)` path instead
    of `SpriteSheet.placeholder(...)`. Use `walk` during slide in/out and `idle`
    while the cat is stopped showing the bubble.
  - `build.sh` will need to copy `Resources/` into
    `Puddles.app/Contents/Resources/`, and the code should load via
    `Bundle.main`.
- Preferences window (currently a stub): make the reminder interval
  configurable.

## Conventions / gotchas

- Keep it SwiftPM + Command Line Tools only (see constraint above).
- The transparent overlay panel captures clicks over its full frame while
  visible (~10s) — acceptable for now; tighten the window or add click-through
  in empty regions once real art lands.
- Build artifacts (`.build/`, generated `Puddles.app/`) are git-ignored; commit
  source only.
