//
//  LaunchAtLoginToggle.swift
//  Gloaming
//
//  The shared "Launch at Login" toggle used by both the menu and the settings window.
//

import SwiftUI

struct LaunchAtLoginToggle: View {
	let launchAtLogin: LaunchAtLogin

	var body: some View {
		// Explicit closures: a method reference here makes the Swift 6.3.2 frontend crash in IRGen
		// (reabstraction thunk under NonisolatedNonsendingByDefault).
		Toggle(
			"Launch at Login",
			isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) })
		)
		.onAppear { launchAtLogin.refresh() }
	}
}
