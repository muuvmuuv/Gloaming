//
//  AppearanceController.swift
//  Gloaming
//
//  Reads and sets the system-wide appearance via a private SkyLight symbol, with an osascript fallback.
//

import Foundation
import OSLog

/// Reads and applies the global Light/Dark appearance.
///
/// The primary path is the private `SLSSetAppearanceThemeLegacy` SkyLight symbol resolved via `dlsym`
/// (silent, no prompt). If that symbol ever disappears we fall back to driving `System Events` through
/// `osascript`. Reading is always done from the public `AppleInterfaceStyle` default.
final class AppearanceController {
	private typealias SetAppearanceThemeLegacy = @convention(c) (Bool) -> Void

	private(set) var isUsingScriptFallback = false

	/// Resolved lazily exactly once and cached; `nil` means the symbol was unavailable and the osascript
	/// fallback must be used instead.
	private lazy var setAppearanceTheme: SetAppearanceThemeLegacy? = Self.resolveSetAppearanceTheme()

	func current() -> Appearance {
		UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" ? .dark : .light
	}

	func set(_ appearance: Appearance) {
		// No read-back confirmation here: the AppleInterfaceStyle default is updated asynchronously, so
		// an immediate current() would report the old value on every successful change. The Scheduler
		// re-syncs from the system via the distributed theme-change notification instead.
		let wantsDark = appearance == .dark
		if let setAppearanceTheme {
			setAppearanceTheme(wantsDark)
		} else {
			setViaAppleScript(dark: wantsDark)
		}
	}

	// MARK: - SkyLight symbol resolution

	private static func resolveSetAppearanceTheme() -> SetAppearanceThemeLegacy? {
		let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
		guard let handle = dlopen(path, RTLD_LAZY) else {
			Log.appearance.error("Could not dlopen SkyLight framework")
			return nil
		}
		guard let symbol = dlsym(handle, "SLSSetAppearanceThemeLegacy") else {
			Log.appearance.error("SLSSetAppearanceThemeLegacy unavailable; will use osascript fallback")
			return nil
		}
		return unsafeBitCast(symbol, to: SetAppearanceThemeLegacy.self)
	}

	// MARK: - osascript fallback

	private func setViaAppleScript(dark: Bool) {
		if !isUsingScriptFallback {
			isUsingScriptFallback = true
			Log.appearance.notice("Falling back to osascript to set the system appearance")
		}

		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
		process.arguments = [
			"-e",
			"tell application \"System Events\" to tell appearance preferences to set dark mode to \(dark)",
		]
		do {
			try process.run()
			process.waitUntilExit()
		} catch {
			Log.appearance.error("osascript fallback failed: \(error.localizedDescription, privacy: .public)")
		}
	}
}
