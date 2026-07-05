//
//  GloamingApp.swift
//  Gloaming
//
//  @main entry point: builds the object graph and hosts the menu-bar and settings scenes.
//

import SwiftUI

@main
struct GloamingApp: App {
	@State private var settings: SettingsStore
	@State private var location: LocationProvider
	@State private var scheduler: Scheduler
	@State private var launchAtLogin = LaunchAtLogin()

	init() {
		let settings = SettingsStore()
		let location = LocationProvider()
		let appearance = AppearanceController()
		let scheduler = Scheduler(settings: settings, location: location, appearance: appearance)
		_settings = State(initialValue: settings)
		_location = State(initialValue: location)
		_scheduler = State(initialValue: scheduler)

		// The unit-test host loads the app; activating would flip the user's real appearance and
		// trigger a CoreLocation (TCC) prompt during testing, so wire the scheduler only for real runs.
		if !Self.isRunningTests {
			scheduler.activate()
		}
	}

	/// True when hosted by the XCTest runner (Swift Testing runs inside the same host process).
	private static var isRunningTests: Bool {
		ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
	}

	var body: some Scene {
		MenuBarExtra {
			MenuBarView(scheduler: scheduler, launchAtLogin: launchAtLogin)
		} label: {
			MenuBarIcon(scheduler: scheduler)
		}
		.menuBarExtraStyle(.menu)

		Settings {
			SettingsView(scheduler: scheduler, launchAtLogin: launchAtLogin)
		}
		.windowResizability(.contentSize)
	}
}
