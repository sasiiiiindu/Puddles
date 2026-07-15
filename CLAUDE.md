# Puddles

A native macOS **menu bar** app (Swift) that reminds you to drink water. When a
reminder fires, a **pixel-art cat** walks in from a randomly chosen screen edge
(left or right), shows a cloud-style pixel speech bubble with a short hydration
message, waits, then turns around and walks back off.

## Hard constraint: Swift Package Manager only, no Xcode

This project is built with **SwiftPM and the Command Line Tools only** — assume
no full Xcode / no `.xcodeproj` is available. Everything is driven from
`Package.swift` and `build.sh`. Do not introduce an Xcode project or dependency
on `xcodebuild`.

- `Package.swift` — executable target `Puddles`, macOS 13+, AppKit.
- `build.sh` — runs `swift build -c release`, then assembles `Puddles.app` by
  hand: copies the binary into `Contents/MacOS/`, copies `Resources/` into
  `Contents/Resources/`, writes `Info.plist` (with `LSUIElement = true` so it's
  menu-bar-only, no dock icon), and ad-hoc signs.

## Build & run

```bash
# Build (produces ./Puddles.app)
./build.sh

# Launch in the menu bar (droplet icon near the clock; no dock icon)
open Puddles.app

# Quit
pkill -x Puddles   # or use the menu's "Quit Puddles" item
```

### Demo / testing flags

Run the binary directly with a flag to fire a reminder ~1s after launch (no need
to wait for the timer). Running in the foreground also surfaces `NSLog` output.

```bash
./Puddles.app/Contents/MacOS/Puddles --demo         # random entry edge
./Puddles.app/Contents/MacOS/Puddles --demo-left    # force entry from the left
./Puddles.app/Contents/MacOS/Puddles --demo-right   # force entry from the right
```

The `--demo-left/right` flags force the entry edge (handy for verifying the
sprite flip and tail aiming); normal timer-driven reminders still pick randomly.

## Source layout (`Sources/Puddles/`)

- `main.swift` — entry point; `.accessory` activation policy (belt-and-suspenders
  with `LSUIElement`).
- `AppDelegate.swift` — status item + menu ("Remind me now", "Preferences…"
  stub, "Quit"), the repeating reminder timer (default **60 min**), and
  `fireReminder()` which logs and shows the overlay. Honors the `--demo`,
  `--demo-left`, `--demo-right` flags.
- `ReminderOverlayController.swift` — owns one overlay: a borderless,
  transparent, always-on-top, **non-activating** `NSPanel` flush to a randomly
  chosen left/right edge, at a random vertical position (avoiding top/bottom
  ~15%). Choreography: walk in (~1.5s) playing `walk` → stop, switch to `idle`,
  pop the speech bubble with a random message → wait 8s → turn around (flip) and
  walk back off the same edge → close. Movement is driven by a **manual 60fps
  timer slide** (`slide(_:toX:duration:)`), not `NSView.animator()` — the
  animator proxy was intermittently teleporting the sprite. Clicking the
  cat/bubble dismisses immediately. Only one overlay shows at a time.
- `SpriteView.swift` — layer-backed view that cycles sprite frames, drawn at
  **5× scale with nearest-neighbor** (`interpolationQuality = .none`) so pixels
  stay crisp; flips horizontally to face its walking direction. `play(sheet:fps:)`
  swaps the sheet/rate at runtime (walk @ 8fps, idle @ 2fps).
- `SpriteSheet.swift` — loads a horizontal PNG sheet and slices it into
  `CGImage` frames. `fromResource(named:frameCount:)` loads bundled art via
  `Bundle.main`; `PlaceholderSprite` generates an in-memory fallback sheet.
- `SpeechBubbleView.swift` — cloud-style pixel speech bubble. Builds the
  silhouette as a pixel **mask** (core text rect + a ring of overlapping discs
  for the cloud bumps + a triangular tail), then outlines it by eroding the mask
  1px, and scales up nearest-neighbor. Sizes itself to its text via
  `fittedSize()`; `tailFraction` aims the tail at the cat.
- `PixelFont.swift` — a hand-authored **3×5 bitmap font** (uppercase, digits,
  basic punctuation) rendered as solid pixel blocks, so text matches the cat's
  pixel grid and stays crisp. Bubble and text share the same art-pixel size.

## Art assets (`Resources/`)

- `walk.png` — **4 frames**, 16×16 each (horizontal sheet, 64×16). Played during
  slide in/out. Assumed drawn **facing left** (the un-mirrored orientation).
- `idle.png` — **2 frames**, 16×16 each (horizontal sheet, 32×16). Looped (slow
  blink) while the bubble is showing.

## Current state

- **Phase 1 (done):** menu bar app, `LSUIElement`/accessory (no dock icon),
  menu, repeating reminder timer.
- **Phase 2 (done):** full overlay animation — walk in, speech bubble, idle,
  walk off, close; click-to-dismiss. Sprite pipeline (sheet → slice → cycle →
  5× nearest-neighbor render) driven by a placeholder sprite.
- **Phase 3 (done):** real sprite sheets wired up (`walk`/`idle` from
  `Resources/`); random left/right entry with correct sprite flipping and
  tail aiming; randomized hydration messages; manual-timer slide (fixed a
  walk-back teleport bug); custom bitmap `PixelFont`; compact cloud-style pixel
  speech bubble.

## What's next

- Preferences window (currently a stub): make the reminder interval
  configurable.

## Conventions / gotchas

- Keep it SwiftPM + Command Line Tools only (see constraint above).
- Bubble and text are composed on an art-pixel grid then upscaled
  nearest-neighbor — keep that pipeline (don't upscale anti-aliased system text).
- Movement uses the manual `slide()` timer, **not** `NSView.animator()` (which
  was teleporting the sprite). Keep it that way.
- The transparent overlay panel captures clicks over its full frame while
  visible (~10s) — acceptable for now; tighten the window or add click-through
  in empty regions later.
- Build artifacts (`.build/`, generated `Puddles.app/`) are git-ignored; commit
  source only. Real art in `Resources/` **is** committed.
