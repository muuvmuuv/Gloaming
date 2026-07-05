# CLAUDE.md

This file provides guidance to Claude Code (or any other agent) when working with code in this
repository.

## Project overview

Gloaming is a macOS menu-bar utility that switches the **system-wide** Light/Dark appearance based
on local sunrise/sunset, with configurable minute offsets.

**Target:** macOS 14+, Swift 6, SwiftUI `MenuBarExtra`. No third-party dependencies — solar math,
location handling, and appearance switching are all implemented in-repo.

Build settings shape how code is written here: `SWIFT_VERSION = 6.0`,
`SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Every type is
implicitly `@MainActor` unless explicitly marked `nonisolated` — pure/model types (`Appearance`,
`SolarCalculator`, `TransitionPlanner`, `Log`) are marked `nonisolated` on purpose; don't fight the
default with `@unchecked Sendable` workarounds.

Read [ARCHITECTURE.md](ARCHITECTURE.md) for the module map and data flow.

## THE NON-NEGOTIABLES

These are deliberate decisions, not oversights. Do not "helpfully" undo them.

1. **Appearance switching uses the private SkyLight symbol `SLSSetAppearanceThemeLegacy`,**
   resolved at runtime via `dlsym`. There is no public API for system-wide appearance — never
   try to "fix" this by switching to a public one; there isn't one. Keep the `osascript`
   (`System Events`) fallback as the resilience net for if a future macOS removes the symbol.
2. **Never enable App Sandbox.** Sandboxing would block both the SkyLight private framework and
   the location access this app needs. `Gloaming.entitlements` intentionally has no
   `com.apple.security.app-sandbox` key.
3. **Never add a Mac App Store pipeline.** The private-API switch cannot pass App Review; there
   is no sandboxed fallback worth shipping. Distribution is Developer ID + notarization only.
4. **Distribution is Developer ID + notarization via the tag-driven GitHub Actions workflow**
   (`.github/workflows/release.yml`). Pushing a `v*` tag signs, notarizes, staples, packages a
   DMG, and creates a GitHub Release. Pushes to `main` and every PR only build, lint, and test.
5. **Files dropped into `Gloaming/` or `GloamingTests/` auto-join their target.** The project uses
   `PBXFileSystemSynchronizedRootGroup` (Xcode 16+ synchronized folders), a hand-written and
   deliberately tiny `project.pbxproj` — never regenerate or convert the project with
   `xcodegen`/`tuist`, and never hand-edit `project.pbxproj` to add file references.

## Build commands

A `justfile` covers everything; run `just --list` for the canonical list.

| Command      | What it does                                                       |
| ------------ | ------------------------------------------------------------------- |
| `just format`| Formats all Swift files in place (`swift format --in-place`).       |
| `just lint`  | Checks formatting (`swift format lint`) and runs `swiftlint`.     |
| `just build` | Debug build via `xcodebuild`.                                       |
| `just build-release` | Release build (Hardened Runtime on).                         |
| `just test`  | Runs the hosted `GloamingTests` target.                               |
| `just clean` | `xcodebuild clean`.                                                  |
| `just open`  | Opens `Gloaming.xcodeproj` in Xcode.                                  |
| `just icon`  | Regenerates `AppIcon.appiconset` PNGs from `scripts/generate-appicon.swift`. |
| `just check` | `format` + `build` + `test`, in that order.                          |

`Package.swift` exists only for SourceKit-LSP support in editors like VS Code — it is not the
build system. Always build/test via `Gloaming.xcodeproj` (through `just` or `xcodebuild`
directly), never `swift build`/`swift test`.

## Tests

`just test` runs the hosted Swift Testing target `GloamingTests`. Because tests run inside the
real app process, `GloamingApp` checks the `XCTestConfigurationFilePath` environment variable and
skips `Scheduler.activate()` when it's set — **never remove that guard**; without it, running
tests would flip the user's live system appearance and could trigger unwanted TCC location
prompts. Pure logic (`SolarCalculator`, `TransitionPlanner`, `Appearance`) needs no such guard
since it has no side effects.

## Formatting & linting

Formatting is Apple's `swift-format` (bundled with Xcode; config in `.swift-format`, tabs, 120
columns) — deliberately not Nick Lockwood's SwiftFormat, to avoid a second toolchain dependency.
Linting is SwiftLint (`.swiftlint.yml`), installed locally via `mint`. `lefthook.yml` runs both
plus a Conventional Commits check on every commit; install the hooks once with `lefthook install`.

Commit messages must match Conventional Commits
(`^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9-]+\))?!?: .+`) — the
`commit-msg` hook enforces this.

## Code style

- Tabs for indentation, 120-column limit.
- `///` doc comments only where the API isn't self-explanatory; comments explain constraints code
  can't express (e.g. *why* something is `nonisolated`), not what the next line does.
- No thin wrapper functions, no speculative abstractions, no singletons. Readable over clever.
- Logging goes through the shared `Log` enum (`Gloaming/Core/Logger.swift`) — one `Logger` per
  subsystem area (`appearance`, `solar`, `location`, `scheduler`), not ad hoc `print`/`NSLog`.
