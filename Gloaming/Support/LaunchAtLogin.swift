//
//  LaunchAtLogin.swift
//  Gloaming
//
//  SMAppService wrapper backing the "Launch at Login" toggles.
//

import OSLog
import Observation
import ServiceManagement

@Observable final class LaunchAtLogin {
	private(set) var isEnabled: Bool

	init() {
		isEnabled = SMAppService.mainApp.status == .enabled
	}

	func setEnabled(_ enabled: Bool) {
		do {
			if enabled {
				try SMAppService.mainApp.register()
			} else {
				try SMAppService.mainApp.unregister()
			}
		} catch {
			let action = enabled ? "register" : "unregister"
			Log.launchAtLogin.error("Launch-at-login \(action) failed: \(error.localizedDescription)")
		}
		// Re-read the authoritative status so the UI never reflects a failed request.
		refresh()
	}

	func refresh() {
		isEnabled = SMAppService.mainApp.status == .enabled
	}
}
