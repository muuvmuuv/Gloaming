# Architecture

This document describes the module layout, data flow, and key decisions behind Sundial.

## Module map

```
Sundial/
├── App/
│   └── SundialApp.swift          # @main, MenuBarExtra scene; skips Scheduler.activate() under test
├── Menu/
│   ├── MenuBarView.swift         # menu contents, live "… until HH:MM" label
│   └── MenuBarIcon.swift         # SF Symbol selection by current appearance/enabled state
├── Core/
│   ├── Appearance.swift          # Appearance enum (light/dark), pure
│   ├── Logger.swift              # Log enum — one OSLog Logger per subsystem area
│   ├── AppearanceController.swift # reads/writes system appearance (SkyLight + osascript fallback)
│   ├── SolarCalculator.swift     # NOAA sunrise/sunset math, pure, Foundation-only
│   ├── TransitionPlanner.swift   # pure decision: desired appearance + next transition boundary
│   ├── Scheduler.swift           # owns timers/observers, wires everything together
│   └── LocationProvider.swift    # CoreLocation wrapper + manual coordinate override
├── Settings/
│   ├── SettingsStore.swift       # @Observable, UserDefaults-backed preferences
│   └── SettingsView.swift        # location mode, offsets, launch-at-login, credit footer
├── Support/
│   ├── LaunchAtLogin.swift       # SMAppService wrapper
│   └── LaunchAtLoginToggle.swift # the shared toggle view used by menu + settings
├── Assets.xcassets               # AppIcon (regenerate via `just icon`)
└── Sundial.entitlements          # Hardened Runtime + location; no App Sandbox
```

`SolarCalculator`, `TransitionPlanner`, and `Appearance` are `nonisolated` and free of
AppKit/CoreLocation — they're pure functions over `Date`/coordinates, which is what makes them
cheap to unit test in `SundialTests`.

## Data flow

```
SettingsStore ──┐
                ├──▶ Scheduler.refresh() ──▶ TransitionPlanner.plan(...) ──▶ AppearanceController.set(_:)
LocationProvider┘            │
                              └──▶ schedules a Timer for the next transition boundary
```

1. `SettingsStore` and `LocationProvider` are both `@Observable`; `Scheduler` holds references to
   both and reacts to their `onChange`/`onUpdate` callbacks.
2. `Scheduler.refresh()` is the decision ladder:
   - Not enabled → `.disabled`, appearance left untouched.
   - No usable coordinate (no fix yet, no manual override, or permission denied) → `.needsLocation`.
   - Otherwise call `TransitionPlanner.plan(...)` with the effective coordinate and offsets, apply
     `plan.desired` via `AppearanceController.set(_:)` if it differs from the current appearance,
     and arm a single timer for `plan.nextTransition`.
   - A manual override in progress short-circuits the ladder into `.pausedByOverride` (see below).
3. After applying, `Scheduler` records the value it just set (the `AppleInterfaceStyle` default
   updates asynchronously, so an immediate read-back would report the *old* value). The system's
   distributed `AppleInterfaceThemeChangedNotification` then re-syncs `currentAppearance` from
   reality — which also keeps the menu-bar glyph truthful when the user flips appearance in System
   Settings. External flips are only *reflected*, never immediately fought.

**Recompute triggers:** app launch, wake from sleep (which also requests a fresh location fix in
automatic mode), local day change (midnight rollover), system clock/timezone change, a new location
fix, any settings change, and the scheduled transition timer firing. `Scheduler.activate()` wires
all of these observers; it is only called once, by the app, and is skipped entirely when
`XCTestConfigurationFilePath` is set, so tests never touch the live appearance.

## Override lifecycle

"Toggle appearance now" is a manual escape hatch, not a permanent switch-off:

1. User toggles → `Scheduler.toggleAppearanceNow()` flips the appearance immediately and moves
   `status` to `.pausedByOverride(until:)`, where `until` is the next natural transition boundary
   computed from the *current* plan.
2. While paused, recompute triggers still run (so wake/clock-change keep the override coordinate
   fresh) but `refresh()` does not fight the manual choice.
3. Once `now >= until`, the next `refresh()` clears the pause and automation resumes normally from
   the decision ladder above.

## Polar-edge behavior

`SolarCalculator.daylight(on:)` reports each civil day as `.sunriseSunset`, `.polarDay` (midnight
sun), or `.polarNight`. `TransitionPlanner.plan` evaluates yesterday/today/tomorrow so offsets
crossing midnight still resolve; a polar day counts as one light window spanning the whole civil
day (offsets are meaningless without sun events), and a polar night contributes no window. Deep
polar night therefore resolves to Dark and deep midnight sun to Light — including the boundary
days where only a neighboring day still has real sun events. `plan` returning `nil` (calendar
arithmetic failure only) makes `Scheduler` hold the current appearance as `.active(next: nil)`
and re-evaluate on the next day-change trigger rather than busy-polling.

## Decisions

- **Hand-written, synchronized `project.pbxproj` instead of XcodeGen.** The plan suggested
  XcodeGen/Tuist for reproducibility; we use Xcode 16's `PBXFileSystemSynchronizedRootGroup`
  folders instead. Any `.swift` file dropped into `Sundial/` or `SundialTests/` auto-joins its
  target, the pbxproj stays tiny and diff-friendly, and there's no extra generator dependency or
  generation step to keep in sync.
- **Apple `swift-format` instead of Nick Lockwood's SwiftFormat.** It ships with Xcode, needs no
  extra install, and the project's `.swift-format` config (tabs, 120 columns) covers what we need.
  SwiftLint remains for idiom/style rules that formatting alone doesn't cover.
- **Hosted Swift Testing target, guarded by `XCTestConfigurationFilePath`.** Running tests in-app
  (rather than a separate logic-only target) lets tests exercise `@MainActor` types directly; the
  guard in `SundialApp` keeps `Scheduler.activate()` from ever running under test, so test runs
  can't flip the real system appearance or prompt for location/TCC permissions.
- **Hardened Runtime is Debug-off, Release-on.** Debug needs it off so Xcode/the test host can
  inject the test bundle; Release turns it on because notarization requires it. The SkyLight
  `dlopen`/`dlsym` call is compatible with Hardened Runtime, so this costs nothing at release time.
- **One-shot reduced-accuracy location + significant-change monitoring**, not continuous tracking.
  Sunrise/sunset only needs city-level accuracy, and a single fix plus significant-change updates
  (recomputed on wake/day-change anyway) is enough to keep the schedule correct without keeping
  CoreLocation running continuously or asking for more precision than the feature needs.
