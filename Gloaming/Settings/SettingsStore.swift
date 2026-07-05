//
//  SettingsStore.swift
//  Gloaming
//
//  Observable, UserDefaults-backed user preferences.
//

import Foundation

/// The user's persisted preferences. Each property writes through to `UserDefaults` and fires `onChange`
/// so the `Scheduler` can react to edits made from the settings window.
@Observable final class SettingsStore {
	nonisolated enum LocationMode: String {
		case automatic = "auto"
		case manual
	}

	/// Permitted range for both sunrise and sunset offsets, in minutes.
	static let offsetRange: ClosedRange<Int> = -240...240

	var isEnabled: Bool {
		didSet {
			defaults.set(isEnabled, forKey: "enabled")
			onChange?()
		}
	}

	var locationMode: LocationMode {
		didSet {
			defaults.set(locationMode.rawValue, forKey: "locationMode")
			onChange?()
		}
	}

	var manualLatitude: Double? {
		didSet {
			persistOptional(manualLatitude, forKey: "manualLatitude")
			onChange?()
		}
	}

	var manualLongitude: Double? {
		didSet {
			persistOptional(manualLongitude, forKey: "manualLongitude")
			onChange?()
		}
	}

	var sunriseOffsetMinutes: Int {
		didSet {
			let clamped = Self.clampOffset(sunriseOffsetMinutes)
			guard clamped == sunriseOffsetMinutes else {
				sunriseOffsetMinutes = clamped  // re-enters didSet with an in-range value
				return
			}
			defaults.set(sunriseOffsetMinutes, forKey: "sunriseOffsetMinutes")
			onChange?()
		}
	}

	var sunsetOffsetMinutes: Int {
		didSet {
			let clamped = Self.clampOffset(sunsetOffsetMinutes)
			guard clamped == sunsetOffsetMinutes else {
				sunsetOffsetMinutes = clamped  // re-enters didSet with an in-range value
				return
			}
			defaults.set(sunsetOffsetMinutes, forKey: "sunsetOffsetMinutes")
			onChange?()
		}
	}

	/// Set by the `Scheduler`; invoked once after any persisted property changes.
	@ObservationIgnored var onChange: (() -> Void)?

	@ObservationIgnored private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults

		// `enabled` defaults to true when absent; use object(forKey:) to tell "absent" from an explicit false.
		isEnabled = defaults.object(forKey: "enabled") as? Bool ?? true
		locationMode = LocationMode(rawValue: defaults.string(forKey: "locationMode") ?? "") ?? .automatic
		manualLatitude = defaults.object(forKey: "manualLatitude") as? Double
		manualLongitude = defaults.object(forKey: "manualLongitude") as? Double
		sunriseOffsetMinutes = Self.clampOffset(defaults.integer(forKey: "sunriseOffsetMinutes"))
		sunsetOffsetMinutes = Self.clampOffset(defaults.integer(forKey: "sunsetOffsetMinutes"))
	}

	private func persistOptional(_ value: Double?, forKey key: String) {
		if let value {
			defaults.set(value, forKey: key)
		} else {
			defaults.removeObject(forKey: key)
		}
	}

	private static func clampOffset(_ value: Int) -> Int {
		min(max(value, offsetRange.lowerBound), offsetRange.upperBound)
	}
}
