# Gloaming

Gloaming is a small macOS menu-bar utility that switches the **system-wide** Light/Dark
appearance based on your local sunrise and sunset — with configurable offsets, so you can, say,
stay in Light mode for an hour after sunrise and switch to Dark an hour before sunset.

- **Solar schedule, not a clock.** Computes today's sunrise/sunset from your location, on-device.
- **Configurable offsets.** Shift the sunrise and sunset transition points by up to four hours in
  either direction.
- **Manual override.** Toggle appearance from the menu at any time; Gloaming pauses automation
  until the next natural transition, then resumes.
- **Launch at login**, kept in sync between the menu and Settings.
- **Manual coordinates.** No location permission? Set latitude/longitude by hand instead.
- **No network access, ever.** All solar math happens on your Mac; nothing is sent anywhere.

## Install

Download the latest notarized `.dmg` from [GitHub Releases](../../releases), open it, and drag
Gloaming into `/Applications`.

## First run

Gloaming changes the appearance itself — it doesn't rely on macOS's own scheduler. So that the two
don't fight each other, open **System Settings > Appearance** and set it to **Light** or **Dark**
(not **Auto**) once, then let Gloaming take it from there.

Gloaming will ask for permission to use your location; this is used only to compute sunrise and
sunset times (city-level accuracy is plenty) and never leaves your Mac. If you'd rather not grant
it, open Gloaming's settings and enter manual coordinates instead.

## How it works

Because there is no public API to change the system-wide appearance, Gloaming calls the private
`SLSSetAppearanceThemeLegacy` SkyLight function (resolved at runtime via `dlsym`, with an
AppleScript-driven fallback if that symbol ever disappears from macOS). Private APIs are not
permitted on the Mac App Store, so Gloaming is distributed independently: signed with a Developer
ID certificate and notarized by Apple, downloaded straight from GitHub Releases.

## Building from source

Requires Xcode 26 or later (Swift 6.2, macOS 14+ deployment target).

```sh
git clone <this-repository>
cd GloamingMac
just build
just test
```

Linting uses [SwiftLint](https://github.com/realm/SwiftLint), installed locally via
[mint](https://github.com/yonaskolb/Mint) (`mint install realm/SwiftLint`); formatting uses
Apple's `swift-format`, bundled with Xcode. To get the same checks locally on every commit,
install the [lefthook](https://github.com/evilmartians/lefthook) git hooks once:

```sh
lefthook install
```

See `just --list` for the full set of development commands, and `CLAUDE.md` /
`ARCHITECTURE.md` for the project's design decisions.

## Credit

Inspired by the nice app Sundial from muuvmuuv for VS Code
(<https://github.com/muuvmuuv/vscode-sundial>). This is an independent native port of the same
idea.

## License

MIT — see [LICENSE](LICENSE).
