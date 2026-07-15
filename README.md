# Puddles 🐱💧

A pixel-art cat that reminds you to drink water, living quietly in your macOS menu bar.

<!-- Replace docs/demo.gif with a real screen recording before release. -->
<p align="center">
  <img src="docs/demo.gif" alt="Puddles demo — a pixel cat walks in with a speech bubble" width="480">
</p>

When it's time to hydrate, a little pixel cat strolls in from the edge of your
screen, holds up a cloud speech bubble, and waits. Click the cat to say "yes, I
drank" — Puddles keeps a tally for the day.

## Features

- 🐱 **Pixel-art cat** that walks in from a random screen edge, shows a
  cloud-style pixel speech bubble, then walks back off.
- 💧 **Glass counter** — click the cat to count a glass; the menu shows
  "Today: N glasses 💧", resetting at midnight.
- ⏰ **Configurable interval** — remind every 15 minutes to 3 hours.
- 🌙 **Active hours** — no reminders outside the window you set.
- 🔔 **Optional sound** — a soft chime when the cat appears.
- 🚀 **Launch at login** — via `SMAppService`.
- 🪟 **Menu bar only** — no dock icon, stays out of your way.
- 🛠️ **No Xcode required** — builds with Swift Package Manager and the Command
  Line Tools alone.

## Installation

1. Download the latest `Puddles-x.y.dmg` from the
   [Releases](../../releases) page.
2. Open the DMG and drag **Puddles** into your **Applications** folder.
3. **First launch:** because Puddles is not code-signed with an Apple Developer
   account, Gatekeeper will block a normal double-click. To open it the first
   time:
   - **Right-click** (or Control-click) `Puddles.app` → **Open**
   - In the dialog that appears, click **Open** again.

   You only need to do this once. After that, launch it normally.

The droplet icon will appear in your menu bar — no dock icon, no window.

> Requires **macOS 13 (Ventura)** or later.

## Build from source

Puddles builds with **only the Command Line Tools** — you do not need a full
Xcode install.

```bash
# One-time: install the Command Line Tools if you don't have them
xcode-select --install

# Clone and build
git clone https://github.com/YOUR_USERNAME/Puddles.git
cd Puddles
./build.sh

# Launch
open Puddles.app
```

`build.sh` runs `swift build -c release` and assembles a proper `Puddles.app`
bundle (with `LSUIElement` set so it's menu-bar-only) — no `.xcodeproj` involved.

### Handy flags (for development)

Run the binary directly to exercise the overlay without waiting for the timer:

```bash
./Puddles.app/Contents/MacOS/Puddles --demo    # fire a reminder ~1s after launch
./Puddles.app/Contents/MacOS/Puddles --prefs   # open the Preferences window
```

## Packaging a release

`release.sh` builds the app and packages it into a drag-to-Applications DMG
using the free [`create-dmg`](https://github.com/create-dmg/create-dmg) tool:

```bash
brew install create-dmg   # one-time
./release.sh 1.0          # produces dist/Puddles-1.0.dmg
```

## Contributing

Contributions are welcome! A few notes to keep things consistent:

- Keep it **Swift Package Manager + Command Line Tools only** — please don't add
  an Xcode project or third-party dependencies.
- Build and smoke-test with `./build.sh` before opening a PR.
- Match the surrounding style; keep changes focused.

Bug reports and feature ideas are welcome via
[Issues](../../issues).

## License

[MIT](LICENSE) © 2026 Sasindu Janapriya
