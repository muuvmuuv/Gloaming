# Sundial (macOS) — Implementation Brief for Claude Code

A native macOS menu-bar utility that switches the **system-wide** appearance between
Light and Dark based on local sunrise/sunset, with configurable offsets (e.g. +60 min
after sunrise, −60 min before sunset).

> Inspired by the nice app **Sundial** from muuvmuuv for VS Code
> (<https://github.com/muuvmuuv/vscode-sundial>). This is an independent native port of
> the same idea; put this line in the README and the About panel.

---

## 0. Non-negotiable design constraint (read first)

There is **no public API** to set the global appearance. `NSAppearance`/
`NSApp.effectiveAppearance` only *read* it. Flipping the whole system requires one of:

1. **Private SkyLight symbol** `SLSSetAppearanceThemeLegacy(Bool)` — silent, no prompt.
   Used by every comparable app. **Banned on the Mac App Store.**
2. **Apple Events automation** of `System Events` (`set dark mode`) — public, but throws a
   TCC Automation prompt, is fragile under App Sandbox, and Apple generally rejects it for
   appearance control.

### Distribution decision: Developer ID + notarization, shipped via GitHub Releases.
Not the Mac App Store. This is why Nightfall, Gray, DarkNight, NightOwl and Solace all ship
outside the store. It still gives us developer-signed binaries and a full GitHub pipeline.

Primary switch mechanism: **`SLSSetAppearanceThemeLegacy` via `dlsym`** (no build-time link
against a private framework). Ship an AppleScript fallback path behind a compile flag only
if we later want a store-adjacent build — do not build it now.

*If the user later insists on App Store:* the app would have to be sandboxed, drop the
private symbol, and drive appearance through a bundled Shortcut ("Set Appearance") — which
cannot be reliably time-triggered on macOS without a helper and will almost certainly fail
review for this use case. Treat App Store as out of scope.

---

## 1. Target & stack

- **Language/UI:** Swift 6, SwiftUI, `MenuBarExtra` scene.
- **Deployment target:** macOS 14 (Sonoma). Drop back to 13 only if trivial.
- **Architecture:** universal (arm64 + x86_64).
- **No dependencies** unless justified. Solar math is implemented in-repo (see §4). Do not
  pull a solar SPM package unless the inline implementation proves inaccurate.
- **Project generation:** hand-written Xcode project is fine, but prefer an
  **`Package.swift` + XcodeGen (`project.yml`)** or a Tuist setup so the project file is
  reproducible in CI and diff-friendly. Pick XcodeGen unless there's a reason not to.

---

## 2. App behaviour

- Menu-bar-only. **No Dock icon, no main window** on launch → `LSUIElement = true`
  (`Application is agent (UIElement)` in Info.plist).
- Runs in the background continuously; the menu bar item is the only always-present UI.
- On launch, on wake, on location change, and at each computed transition it recomputes and
  applies the correct appearance.
- The app *takes over* appearance. Document (README + first-run note) that the user should
  set macOS **Appearance = Light or Dark (not Auto)** in System Settings, so macOS's own
  Auto scheduler doesn't fight Sundial. Sundial does not need Auto — it is the scheduler.

---

## 3. Menu-bar UI (SF Symbols only — Apple's own icons)

`MenuBarExtra` with a dynamic SF Symbol:

- Currently light → `sun.max` (or `sun.max.fill`)
- Currently dark → `moon.stars` (or `moon.fill`)
- Disabled → `sun.max` with `.secondary`/dimmed rendering

Menu contents (keep it lean):

- A non-interactive header line: current mode + next transition, e.g.
  `Dark until 07:14` / `Light until 20:32`.
- `Toggle appearance now` — manual override; flips immediately and **pauses automation
  until the next natural transition** (mirror Sundial's "manual action disables auto until
  next event" behaviour). Do not permanently disable.
- `Enabled` (checkbox) — master on/off for automation.
- `Settings…` — opens the settings window.
- `Launch at login` (checkbox) — see §7.
- `Quit Sundial`.

Use `MenuBarExtra(..., style: .menu)`. The header/next-transition string updates live.

---

## 4. Solar scheduling (on-device, no network)

### Location
- Default: **CoreLocation**, one-shot / significant-change updates. Request
  `NSLocationUsageDescription` ("Sundial uses your location to compute local sunrise and
  sunset times. It never leaves your Mac."). Use
  `kCLLocationAccuracyReduced` / `requestLocation` — city-level accuracy is plenty.
- Fallback / override: **manual latitude & longitude** text fields (like Sundial). If both
  are set, they win and CoreLocation is not used. If the user denies location and has set
  no manual coordinates, show a dimmed menu-bar icon and a menu note prompting for either.

### Sun times
Implement a self-contained sunrise/sunset calculator (NOAA / standard low-precision solar
position algorithm) as `SolarCalculator`:

```
func sunrise(on date: Date, latitude: Double, longitude: Double) -> Date?
func sunset(on date: Date,  latitude: Double, longitude: Double) -> Date?
```

Use the official-zenith (90°50′) sunrise/sunset. Handle polar edge cases (returns
`nil` → keep current appearance, log, and reschedule for next local midnight). Compute in
UTC internally, convert with the current `TimeZone`.

### Offsets → decision
- `sunriseOffsetMinutes: Int` (default 0), `sunsetOffsetMinutes: Int` (default 0). Signed.
  The user's target = `+60` and `-60`.
- Light window = `[sunrise + sunriseOffset, sunset + sunsetOffset)`.
- `desiredAppearance(at:) -> .light | .dark` from that window.
- On any recompute: apply desired appearance if it differs from current, then schedule the
  next transition timer for the next boundary crossing.

---

## 5. Appearance switching mechanism

`AppearanceController`:

```swift
enum Appearance { case light, dark }

func current() -> Appearance
    // read UserDefaults(AppleInterfaceStyle) == "Dark" ? .dark : .light

func set(_ appearance: Appearance)
    // resolve SLSSetAppearanceThemeLegacy via dlsym and call it
```

Implementation notes:
- `dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)`,
  then `dlsym(handle, "SLSSetAppearanceThemeLegacy")`, cast to
  `@convention(c) (Bool) -> Void`. `true` = dark. Cache the handle.
- Guard the whole thing: if the symbol can't be resolved (future macOS removes it), fall
  back to `osascript` invoking the `System Events` `set dark mode` script, and surface a
  one-time non-blocking notice. Keep the fallback isolated so the happy path stays clean.
- After setting, re-read `current()` to confirm and update menu state.
- Hardened Runtime is required for notarization; the SkyLight `dlopen` is compatible with
  it. Do **not** enable the App Sandbox (it would block the private framework and location
  behaviour we want here).

---

## 6. Settings window

Small, single pane, no tabs. Opened from the menu. Mirror Sundial's simplicity — expose
*only* what's needed:

- **Location:** segmented `Automatic` / `Manual`. Manual reveals two numeric fields
  (latitude, longitude). Show the resolved coordinates + today's computed sunrise/sunset
  read-only underneath so the user can sanity-check.
- **Sunrise offset:** stepper/field in minutes (−240…240).
- **Sunset offset:** stepper/field in minutes (−240…240).
- **Launch at login:** toggle (also in the menu; keep in sync).
- Footer: app name, version, and the muuvmuuv credit line as a clickable link.

No colour-temperature, no wallpaper, no weather, no keyboard shortcut config in v1. Keep it
the "simple" scope the brief asked for.

Window: `Settings` scene or a manually managed `NSWindow` sized ~420×360, non-resizable,
`.titled`, centered. Since `LSUIElement` apps have no menu bar app menu, bring the window to
front with `NSApp.activate(ignoringOtherApps: true)` when opened.

---

## 7. Launch at login & lifecycle

- **Launch at login:** `SMAppService.mainApp.register()` / `.unregister()`
  (ServiceManagement, macOS 13+). No separate helper bundle. Reflect
  `SMAppService.mainApp.status` in both toggles.
- **Wake handling:** observe `NSWorkspace.shared.notificationCenter`
  `didWakeNotification` → recompute + reapply (this is the bug that makes macOS Auto feel
  broken after sleep; we fix it by recomputing on wake).
- **Timers:** schedule the next transition with a single `Timer`/`DispatchSourceTimer`
  targeting the next boundary; also recompute at local midnight (day rollover) and on
  `NSSystemClockDidChange` / significant time-zone changes. Never busy-poll on an interval;
  compute the exact next fire date. (An optional low-frequency safety re-check every ~30 min
  is acceptable but not required.)
- **Location changes:** on significant-location-change, recompute.

---

## 8. Persistence

`UserDefaults` (`@AppStorage` where convenient). Keys: `enabled`,
`locationMode` (`auto`/`manual`), `manualLatitude`, `manualLongitude`,
`sunriseOffsetMinutes`, `sunsetOffsetMinutes`. Launch-at-login state is owned by
`SMAppService`, not persisted separately.

---

## 9. Suggested module layout

```
Sundial/
  App/
    SundialApp.swift            // @main, MenuBarExtra scene, no window on launch
    AppDelegate.swift           // NSApplicationDelegate: wake/clock observers, activation
  Menu/
    MenuBarView.swift           // menu contents, live "…until HH:MM" label
    MenuBarIcon.swift           // SF Symbol selection by state
  Core/
    AppearanceController.swift  // SLSSetAppearanceThemeLegacy via dlsym (+ osascript fallback)
    SolarCalculator.swift       // sunrise/sunset math, pure, unit-testable
    Scheduler.swift             // owns timers, decides + applies desired appearance
    LocationProvider.swift      // CoreLocation wrapper + manual override
  Settings/
    SettingsView.swift
    SettingsStore.swift         // @AppStorage-backed, ObservableObject
  Support/
    LaunchAtLogin.swift         // SMAppService wrapper
  Resources/
    Info.plist                  // LSUIElement, NSLocationUsageDescription, versions
    Sundial.entitlements        // Hardened Runtime; NO app sandbox
    Assets.xcassets             // AppIcon
project.yml                     // XcodeGen
```

Keep `SolarCalculator` free of UIKit/AppKit so it's covered by a small unit test target
(input coords/date → known sunrise/sunset within tolerance). Tests are optional for v1 but
the pure boundary makes them cheap.

---

## 10. Repo conventions

Match the muuvmuuv repo's discipline where it maps to Swift:

- **Conventional Commits** (`config-conventional`).
- **SwiftFormat** + **SwiftLint**, run via **lefthook** pre-commit.
- `CLAUDE.md` / `AGENTS.md` describing the build, the private-API caveat, and the
  distribution decision, so future agent sessions don't "helpfully" try to sandbox it or
  push it to the App Store.
- `CHANGELOG.md` generated on release (tag-driven).
- MIT license.

---

## 11. CI/CD — GitHub Actions (build → sign → notarize → release)

`macos-14` runner. Triggers: PRs build+lint only; tags `v*` do the full signed release.

Secrets required (GitHub → repo → Settings → Secrets):

- `DEVELOPER_ID_APP_CERT_P12_BASE64` — base64 of the exported *Developer ID Application*
  cert + private key (`.p12`).
- `DEVELOPER_ID_APP_CERT_PASSWORD` — the `.p12` password.
- `KEYCHAIN_PASSWORD` — arbitrary, for the ephemeral CI keychain.
- `AC_API_KEY_ID`, `AC_API_ISSUER_ID`, `AC_API_KEY_P8_BASE64` — App Store Connect API key
  for `notarytool` (preferred over Apple-ID + app-specific-password).
- `TEAM_ID` — Apple Developer Team ID (can also be a plain env/var).

Pipeline skeleton (fill in real scheme/paths):

```yaml
name: release
on:
  push:
    tags: ["v*"]
  pull_request:

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app

      - name: Lint
        run: |
          brew install swiftlint swiftformat
          swiftformat --lint .
          swiftlint

      - name: Generate project
        run: |
          brew install xcodegen
          xcodegen generate

      # --- signing keychain (release only) ---
      - name: Import Developer ID cert
        if: startsWith(github.ref, 'refs/tags/')
        env:
          CERT: ${{ secrets.DEVELOPER_ID_APP_CERT_P12_BASE64 }}
          CERT_PW: ${{ secrets.DEVELOPER_ID_APP_CERT_PASSWORD }}
          KC_PW: ${{ secrets.KEYCHAIN_PASSWORD }}
        run: |
          echo "$CERT" | base64 --decode > cert.p12
          security create-keychain -p "$KC_PW" build.keychain
          security set-keychain-settings -lut 21600 build.keychain
          security unlock-keychain -p "$KC_PW" build.keychain
          security import cert.p12 -k build.keychain -P "$CERT_PW" \
            -T /usr/bin/codesign
          security list-keychains -d user -s build.keychain login.keychain
          security set-key-partition-list -S apple-tool:,apple: -s -k "$KC_PW" build.keychain
          rm cert.p12

      - name: Build & archive
        run: |
          xcodebuild -project Sundial.xcodeproj -scheme Sundial \
            -configuration Release -destination 'generic/platform=macOS' \
            -archivePath build/Sundial.xcarchive archive \
            CODE_SIGN_STYLE=Manual \
            CODE_SIGN_IDENTITY="Developer ID Application" \
            DEVELOPMENT_TEAM=${{ secrets.TEAM_ID }} \
            OTHER_CODE_SIGN_FLAGS="--options runtime --timestamp"

      - name: Export .app
        run: |
          xcodebuild -exportArchive \
            -archivePath build/Sundial.xcarchive \
            -exportOptionsPlist ci/ExportOptions.plist \
            -exportPath build/export

      # --- notarize (release only) ---
      - name: Notarize + staple
        if: startsWith(github.ref, 'refs/tags/')
        env:
          KEY_ID: ${{ secrets.AC_API_KEY_ID }}
          ISSUER: ${{ secrets.AC_API_ISSUER_ID }}
          KEY_P8: ${{ secrets.AC_API_KEY_P8_BASE64 }}
        run: |
          echo "$KEY_P8" | base64 --decode > ac_api.p8
          APP="build/export/Sundial.app"
          # zip for submission
          ditto -c -k --keepParent "$APP" build/Sundial.zip
          xcrun notarytool submit build/Sundial.zip \
            --key ac_api.p8 --key-id "$KEY_ID" --issuer "$ISSUER" --wait
          xcrun stapler staple "$APP"
          rm ac_api.p8

      - name: Package DMG
        if: startsWith(github.ref, 'refs/tags/')
        run: |
          brew install create-dmg
          create-dmg --volname "Sundial" --app-drop-link 420 180 \
            build/Sundial.dmg build/export/Sundial.app || true
          # create-dmg returns nonzero on cosmetic warnings; the dmg is still produced.
          test -f build/Sundial.dmg

      - name: GitHub Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v2
        with:
          files: build/Sundial.dmg
          generate_release_notes: true
```

`ci/ExportOptions.plist`: `method = developer-id`, `signingStyle = manual`, `teamID`.

Notes for the agent:
- The lint step runs on every PR; the sign/notarize/release steps are gated to tags.
- Do **not** add a Mac App Store upload step. If asked later, that requires a different cert
  (*Apple Distribution* + a Mac App Store provisioning profile) and `xcrun altool
  --upload-app` / `fastlane deliver`, plus sandboxing — and this app cannot pass review with
  the private-API switch, so leave it out.

---

## 12. Build order for the agent (milestones)

1. Scaffold: XcodeGen `project.yml`, `Info.plist` with `LSUIElement`, entitlements with
   Hardened Runtime (no sandbox), empty `MenuBarExtra` app that shows a static SF Symbol.
2. `AppearanceController` with `SLSSetAppearanceThemeLegacy` via `dlsym` + read-current;
   wire a "Toggle appearance now" menu item and confirm it flips the whole system.
3. `SolarCalculator` (pure) + a unit test against a couple of known coordinates/dates.
4. `LocationProvider` (CoreLocation + manual override) and `SettingsStore`.
5. `Scheduler`: desired-appearance decision, offset handling, next-transition timer, wake +
   midnight + clock-change recompute.
6. Settings window (location mode, offsets, launch-at-login, credit footer).
7. `LaunchAtLogin` via `SMAppService`; keep menu/settings toggles in sync.
8. Live menu header ("… until HH:MM"), icon state, disabled/no-location states.
9. Repo hygiene: SwiftFormat/SwiftLint, lefthook, `CLAUDE.md`, README with credit, MIT.
10. CI: PR build+lint, then the tagged sign/notarize/release pipeline.

---

## 13. Decisions left to the user

- **Bundle identifier** (e.g. `digital.marvin.sundial`) and **Team ID**.
- Whether to keep the AppleScript fallback compiled in at all (recommend: yes, guarded, as
  a resilience net against a future macOS removing the SkyLight symbol).
- Minimum macOS (14 assumed; 13 is a one-line change if wanted).
- App icon artwork (menu-bar glyph is SF Symbols; the `.app` still needs an AppIcon set).
