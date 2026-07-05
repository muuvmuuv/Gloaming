//
//  MenuBarView.swift
//  Gloaming
//
//  Menu-bar dropdown: live status header plus the lean set of controls.
//

import AppKit
import SwiftUI

struct MenuBarView: View {
	@Environment(\.openSettings) private var openSettings

	let scheduler: Scheduler
	let launchAtLogin: LaunchAtLogin

	var body: some View {
		@Bindable var settings = scheduler.settings

		Text(headerText)
		if scheduler.isUsingScriptFallback {
			Text("Using script fallback")
				.foregroundStyle(.secondary)
		}

		Divider()

		Button("Toggle Appearance Now") {
			scheduler.toggleAppearanceNow()
		}
		Toggle("Enabled", isOn: $settings.isEnabled)

		Divider()

		Button("Settings…") {
			NSApp.activate(ignoringOtherApps: true)
			openSettings()
		}
		LaunchAtLoginToggle(launchAtLogin: launchAtLogin)

		Divider()

		Button("Quit Gloaming") {
			NSApp.terminate(nil)
		}
		.keyboardShortcut("q")
	}

	/// Single line describing what automation is doing right now.
	private var headerText: String {
		switch scheduler.status {
		case .disabled:
			return "Automation off"
		case .needsLocation:
			return "Location needed — see Settings"
		case .active(let next):
			let name = scheduler.currentAppearance.rawValue.capitalized
			guard let next else { return name }
			return "\(name) until \(next.formatted(date: .omitted, time: .shortened))"
		case .pausedByOverride(let until):
			guard let until else { return "Paused" }
			return "Paused until \(until.formatted(date: .omitted, time: .shortened))"
		}
	}
}
