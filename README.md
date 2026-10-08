# 🍅 Sugoso

A calm, free, open-source focus timer that lives in your Mac's menu bar. Work in short
focus sessions with short breaks, and a longer break after every four. No Dock icon,
gentle notifications, and it can start automatically when you log in.

---

## Install Sugoso

Both ways work on a brand-new Mac with nothing else set up. **The easiest way is to
download the app, so most people should start there.** If you would rather use the
Terminal, that works too.

## You can download the app

**This is the easiest way, and what most people should use.**

1. **[Download Sugoso.dmg](https://github.com/pohsuchenwork/sugoso/releases/latest/download/Sugoso.dmg)** (about half a megabyte). It saves to your **Downloads** folder.
2. **Double-click `Sugoso.dmg`.** A window opens showing the **Sugoso** app next to your
   **Applications** folder.
3. **Drag the Sugoso icon onto the Applications folder** in that window. That installs it.
4. **Open it.** In Finder, click **Applications** in the left sidebar, then double-click
   **Sugoso**.
5. **The first time only,** macOS will say it cannot verify the developer. That is expected,
   because Sugoso is free and is not paid-notarized yet. To allow it:
   - Open the **Apple menu** (top-left of the screen), then **System Settings**, then
     **Privacy & Security**.
   - Scroll down to the line about Sugoso and click **Open Anyway**, then confirm. You only
     do this once.
   - If instead it says **"Sugoso is damaged"**, open Terminal (Command and Space, type
     `Terminal`), paste the line below, press **Return**, then open Sugoso again:
     ```
     xattr -dr com.apple.quarantine /Applications/Sugoso.app
     ```
6. Look for the tomato in the menu bar at the top-right of your screen.

## Or you can install from the Terminal

If you would rather not download the app, you can build it yourself by copying and pasting
a few commands. You do not need to understand them, and this way never shows a security
prompt.

1. **Open Terminal.** Press **Command and Space** together, type `Terminal`, and press
   **Return**. A small window opens where you can type.
2. **Install Apple's free developer tools** (one time). Copy the line below, paste it into
   Terminal, and press **Return**:
   ```
   xcode-select --install
   ```
   A box pops up. Click **Install** and wait for it to finish (a few minutes). If it says
   the tools are already installed, just continue to the next step.
3. **Download, build, and open Sugoso.** Copy this whole block, paste it into Terminal,
   and press **Return**:
   ```
   cd ~/Downloads && git clone https://github.com/pohsuchenwork/sugoso.git && cd sugoso && ./build.sh && open build/Sugoso.app
   ```
   This downloads Sugoso, builds it, and opens it. Look for the tomato in the menu bar at
   the top-right of your screen.
4. **(Optional) Start Sugoso automatically when you log in.** Paste this and press
   **Return**:
   ```
   cd ~/Downloads/sugoso && ./install.sh
   ```

> The one-time "Open Anyway" step happens only because this build is not notarized yet
> (notarizing needs a paid Apple Developer account). Installing from the Terminal never
> shows it. Once Sugoso is notarized, the downloaded app will open with a normal
> double-click.

## Using Sugoso

- Click the **tomato** in the menu bar. A small panel opens.
- Click **Start**. Focus until it chimes, then take the break it suggests. Repeat.
- On the first run, macOS asks permission to show notifications. Click **Allow** (or later,
  turn it on in System Settings, then Notifications, then Sugoso).
- Change the focus and break lengths right in the panel.

## What you get

- A live countdown in the menu bar (`🍅 24:13`)
- The classic 25 / 5 / 15 cycle, with adjustable lengths that are remembered
- Native notifications when a session ends
- Start, Pause, Skip, and Reset controls
- Optional auto-start at login
- A "Customize with Pro" link, if you want the paid, customizable edition

## To remove Sugoso

- **If you downloaded the app:** quit it from the tomato menu, then drag **Sugoso** from
  Applications to the Trash.
- **If you installed from the Terminal:** quit it, then delete the `sugoso` folder in your
  Downloads. If you ran `install.sh`, also paste these two lines in Terminal:
  ```
  launchctl bootout gui/$(id -u)/com.sugoso.app
  rm ~/Library/LaunchAgents/com.sugoso.app.plist
  ```

---

## For developers

Sugoso is a Swift package: a `SugosoCore` library plus a thin `Sugoso` executable.

- **Requirements:** macOS 13 or later, and Xcode Command Line Tools (`xcode-select --install`).
- **Build:** `./build.sh` compiles and bundles `build/Sugoso.app` (ad-hoc signed for local use).
- **Run the tests:** `swift run Sugoso --run-tests`. Command Line Tools ship neither XCTest nor
  Swift Testing, so the state-machine suite runs as a plain mode of the executable and exits
  non-zero on failure.
- **Distribute to other Macs without a warning:** sign with a Developer ID and notarize (needs
  an Apple Developer account):
  ```
  CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh
  ./notarize.sh
  ```
  `notarize.sh` zips the app, submits it to Apple's notary service, and staples the ticket so
  it opens cleanly anywhere.

### How it works (the tour)

| File | Role |
|------|------|
| `Package.swift` | Swift Package manifest: a `SugosoCore` library plus a thin `Sugoso` executable. |
| `Sources/Sugoso/main.swift` | The app's entry point: picks the branding, then launches the shared scene (or runs `--run-tests`). |
| `Sources/SugosoCore/SugosoApp.swift` | The `MenuBarExtra` scene. |
| `Sources/SugosoCore/Branding.swift` | Cosmetics (name, accent colors, glyphs), applied once via `Theme.configure`. |
| `Sources/SugosoCore/PanelExtension.swift` | Seam for an app to contribute extra panel buttons or pages without modifying the core. |
| `Sources/SugosoCore/Theme.swift` | Design tokens plus the branding seam (`Theme.brand` / `Theme.configure`). |
| `Sources/SugosoCore/PomodoroTimer.swift` | The state machine: sessions, wall-clock countdown, notifications. |
| `Sources/SugosoCore/MenuContentView.swift` | The SwiftUI panel (countdown, buttons, toggles, settings). |
| `Sources/SugosoCore/MenuBarLabel.swift` | Renders the menu bar label (glyph plus time) to an image. |
| `Sources/SugosoCore/BreakOverlay.swift` | The full-screen Liquid Glass break overlay. |
| `Sources/SugosoCore/SelfTests.swift` | Framework-free state-machine tests (`--run-tests`). |
| `Resources/Info.plist` | Bundle metadata. `LSUIElement` hides the Dock icon. |
| `build.sh` | Compiles, bundles, and signs `Sugoso.app` (ad-hoc, or Developer ID via `CODESIGN_IDENTITY`). |
| `notarize.sh` | Notarizes and staples the app for distribution. |
| `install.sh` | Installs the app and loads the LaunchAgent for auto-start. |

## License & legal

**Source code** is released under the **[Apache License 2.0](LICENSE)**: free to use, modify,
and redistribute (including commercially), with an express patent grant and Apache's warranty
and liability disclaimer.

**Using the app, in plain terms** (full text: **[EULA.md](EULA.md)**):

- **Not liable for anything.** Sugoso is provided **"as is" and "as available," with no
  warranty.** To the maximum extent the law allows, the author is **not liable** for any loss
  or damage arising from the app (direct, indirect, incidental, or consequential), and total
  liability is capped at a nominal amount.
- **No upkeep.** No obligation of support, maintenance, updates, uptime, or any service level.
  The author may change, suspend, or discontinue the app **at any time**, without liability.
- **Not responsible for what isn't the author's.** You use Sugoso **at your own risk** and are
  responsible for your device, data, backups, and legal compliance. The author is not
  responsible for your decisions, your content (such as task names, which never leave your
  device), macOS, or any third-party software or service. The break overlay is a visual
  reminder, **not** a screen lock or security feature.
- **Terms can change anytime.** These terms may be updated whenever; the version shipped with
  the app governs, and continued use means you accept it.
- **You indemnify the author** against claims arising from your use of, or your breach of, the
  terms.

> **Why there are limits to the above:** clauses that try to exclude *everything* are usually
> void, which can sink the whole disclaimer. Nothing here removes rights that **cannot** be
> excluded by law, such as mandatory consumer guarantees under consumer protection laws, or
> liability for death or personal injury caused by negligence, or fraud. Keeping those
> carve-outs in is what makes the rest enforceable (see [EULA.md](EULA.md), sections 9 and 9A).

**Privacy:** Sugoso runs entirely on your Mac and **collects no data**: no analytics, no
tracking, and the app makes no network calls of its own (it may offer a link that opens your
browser to the developer's website). Verified in the source. See **[PRIVACY.md](PRIVACY.md)**.

> **Not legal advice.** These documents are a plain-language template adapted for this project;
> some items depend on your jurisdiction and entity (marked `[PLACEHOLDER]` or `[REVIEW]`) and
> should be confirmed by a lawyer in your jurisdiction. "Sugoso" was chosen to avoid the
> "Pomodoro Technique" trademark (claimed by Francesco Cirillo); run your own clearance on the
> name "Sugoso" before relying on it.
