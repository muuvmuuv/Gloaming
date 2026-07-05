//
//  Logger.swift
//  Sundial
//
//  OSLog categories for Sundial's subsystems.
//

import Foundation
import OSLog

/// App-wide logging categories, one `Logger` per subsystem area.
nonisolated enum Log {
	private static let subsystem = Bundle.main.bundleIdentifier ?? "digital.marvin.Sundial"

	static let appearance = Logger(subsystem: subsystem, category: "appearance")
	static let location = Logger(subsystem: subsystem, category: "location")
	static let scheduler = Logger(subsystem: subsystem, category: "scheduler")
	static let launchAtLogin = Logger(subsystem: subsystem, category: "launch-at-login")
}
