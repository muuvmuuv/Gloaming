//
//  SettingsView.swift
//  Gloaming
//
//  Single-pane settings: location, offsets, launch-at-login, and credits.
//

import CoreLocation
import SwiftUI

struct SettingsView: View {
	let scheduler: Scheduler
	let launchAtLogin: LaunchAtLogin

	var body: some View {
		@Bindable var settings = scheduler.settings

		Form {
			Section("Location") {
				Picker("Mode", selection: $settings.locationMode) {
					Text("Automatic").tag(SettingsStore.LocationMode.automatic)
					Text("Manual").tag(SettingsStore.LocationMode.manual)
				}
				.pickerStyle(.segmented)

				if settings.locationMode == .manual {
					TextField("Latitude", value: $settings.manualLatitude, format: .number)
						.font(.body.monospacedDigit())
					if let latitude = settings.manualLatitude, !(-90...90).contains(latitude) {
						Text("Latitude must be between −90 and 90.")
							.font(.caption)
							.foregroundStyle(.red)
					}
					TextField("Longitude", value: $settings.manualLongitude, format: .number)
						.font(.body.monospacedDigit())
					if let longitude = settings.manualLongitude, !(-180...180).contains(longitude) {
						Text("Longitude must be between −180 and 180.")
							.font(.caption)
							.foregroundStyle(.red)
					}
				}

				LabeledContent("Coordinate", value: coordinateSummary)
				LabeledContent("Today", value: sunSummary)

				if scheduler.location.isAuthorizationDenied, settings.locationMode == .automatic {
					Text(
						"Location access is denied. Grant it in System Settings › Privacy & Security › "
							+ "Location Services, or switch to Manual and enter coordinates."
					)
					.font(.caption)
					.foregroundStyle(.secondary)
				}
			}

			Section("Offsets") {
				offsetRow("Sunrise offset", value: $settings.sunriseOffsetMinutes)
				offsetRow("Sunset offset", value: $settings.sunsetOffsetMinutes)
			}

			Section("General") {
				LaunchAtLoginToggle(launchAtLogin: launchAtLogin)
			}

			Section {
				VStack(alignment: .leading, spacing: 8) {
					Text("Gloaming \(appVersion)")
						.foregroundStyle(.secondary)
					// The credit line required verbatim by the product plan (README carries it too).
					Text(
						"Inspired by the nice app Sundial from muuvmuuv for VS Code. "
							+ "This is an independent native port of the same idea."
					)
					.foregroundStyle(.secondary)
					Link(
						"muuvmuuv/vscode-sundial on GitHub",
						destination: URL(string: "https://github.com/muuvmuuv/vscode-sundial")!
					)
					Text(
						"Set the macOS Appearance to Light or Dark (not Auto) in System Settings so "
							+ "macOS's own scheduler doesn't fight Gloaming."
					)
					.font(.caption)
					.foregroundStyle(.secondary)
				}
			}
		}
		.formStyle(.grouped)
		.frame(width: 420)
	}

	/// One offset row: a direct minute field alongside a 5-minute stepper (the store clamps).
	@ViewBuilder
	private func offsetRow(_ title: String, value: Binding<Int>) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Text(title)
				Spacer()
				TextField("", value: value, format: .number)
					.labelsHidden()
					.multilineTextAlignment(.trailing)
					.monospacedDigit()
					.frame(width: 56)
				Stepper(title, value: value, in: SettingsStore.offsetRange, step: 5)
					.labelsHidden()
			}
			Text("minutes, −240 to 240")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}

	private var coordinateSummary: String {
		guard let coordinate = scheduler.effectiveCoordinate else { return "—" }
		return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
	}

	private var sunSummary: String {
		guard let coordinate = scheduler.effectiveCoordinate else { return "—" }
		let sunrise = SolarCalculator.sunrise(on: .now, latitude: coordinate.latitude, longitude: coordinate.longitude)
		let sunset = SolarCalculator.sunset(on: .now, latitude: coordinate.latitude, longitude: coordinate.longitude)
		return "Sunrise \(timeString(sunrise)) · Sunset \(timeString(sunset))"
	}

	private func timeString(_ date: Date?) -> String {
		guard let date else { return "—" }
		return date.formatted(date: .omitted, time: .shortened)
	}

	private var appVersion: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
	}
}
