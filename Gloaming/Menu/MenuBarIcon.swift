//
//  MenuBarIcon.swift
//  Gloaming
//
//  Menu-bar glyph reflecting the current appearance and automation state.
//

import SwiftUI

struct MenuBarIcon: View {
	let scheduler: Scheduler

	var body: some View {
		Image(systemName: symbolName)
			.opacity(isDimmed ? 0.45 : 1)
	}

	/// Plan section 3: light -> sun, dark -> moon; the inactive states always show the dimmed sun.
	private var symbolName: String {
		switch scheduler.status {
		case .disabled, .needsLocation:
			"sun.max"
		case .active, .pausedByOverride:
			scheduler.currentAppearance == .dark ? "moon.stars" : "sun.max"
		}
	}

	/// Dim the glyph while automation is not driving appearance.
	private var isDimmed: Bool {
		switch scheduler.status {
		case .disabled, .needsLocation:
			true
		case .active, .pausedByOverride:
			false
		}
	}
}
