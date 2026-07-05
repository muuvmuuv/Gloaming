//
//  Scheduler.swift
//  Gloaming
//
//  The brain: decides and applies the desired appearance, and schedules the next transition.
//

import AppKit
import CoreLocation
import Foundation
import OSLog

/// Owns the automation loop. On every `refresh()` it reads the current appearance, decides what the
/// appearance should be from the solar schedule, applies it when needed, and arms a single timer for the
/// next boundary. Wake, clock, time-zone and day-rollover notifications all funnel back into `refresh()`.
@Observable final class Scheduler {
	nonisolated enum Status: Equatable {
		case disabled
		case needsLocation
		case active(next: Date?)  // nil next = polar hold, re-evaluates on day change
		case pausedByOverride(until: Date?)  // manual toggle parked automation until the next natural transition
	}

	private(set) var status: Status = .disabled
	private(set) var currentAppearance: Appearance = .light

	let settings: SettingsStore
	let location: LocationProvider

	@ObservationIgnored private let appearance: AppearanceController
	@ObservationIgnored private var transitionTimer: Timer?
	@ObservationIgnored private var overrideUntil: Date?
	@ObservationIgnored private var notificationTokens: [any NSObjectProtocol] = []
	@ObservationIgnored private var didActivate = false

	var isUsingScriptFallback: Bool { appearance.isUsingScriptFallback }

	/// Manual coordinates win when the mode is manual and both values are valid; otherwise the auto fix.
	var effectiveCoordinate: CLLocationCoordinate2D? {
		if settings.locationMode == .manual {
			guard let latitude = settings.manualLatitude, let longitude = settings.manualLongitude,
				(-90...90).contains(latitude), (-180...180).contains(longitude)
			else { return nil }
			return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
		}
		return location.coordinate
	}

	init(settings: SettingsStore, location: LocationProvider, appearance: AppearanceController) {
		self.settings = settings
		self.location = location
		self.appearance = appearance
	}

	/// Wires callbacks and system observers, starts location, and performs the first refresh. Idempotent;
	/// the App calls it once at launch (unit tests construct the `Scheduler` without activating it).
	func activate() {
		guard !didActivate else { return }
		didActivate = true

		settings.onChange = { [weak self] in self?.handleSettingsChange() }
		location.onUpdate = { [weak self] in self?.refresh() }

		observe(NSWorkspace.shared.notificationCenter, name: NSWorkspace.didWakeNotification) { [weak self] in
			self?.handleWake()
		}
		let systemNames: [Notification.Name] = [
			.NSSystemClockDidChange, .NSSystemTimeZoneDidChange, .NSCalendarDayChanged,
		]
		for name in systemNames {
			observe(.default, name: name) { [weak self] in self?.refresh() }
		}

		// Posted after the system appearance actually changed — including changes made outside Gloaming
		// (System Settings, other apps). Only sync the published value; automation is not re-run, so a
		// user flipping appearance elsewhere is not immediately fought.
		let themeChanged = Notification.Name("AppleInterfaceThemeChangedNotification")
		observe(DistributedNotificationCenter.default(), name: themeChanged) { [weak self] in
			guard let self else { return }
			currentAppearance = appearance.current()
		}

		syncLocationMode()
		refresh()
	}

	func refresh() {
		let now = Date()
		currentAppearance = appearance.current()

		guard settings.isEnabled else {
			cancelTransitionTimer()
			status = .disabled
			return
		}

		guard let coordinate = effectiveCoordinate else {
			cancelTransitionTimer()
			status = .needsLocation
			return
		}

		guard let plan = currentPlan(at: now, coordinate: coordinate) else {
			// No day was computable at all: keep the current appearance, wait for the day-change notification.
			cancelTransitionTimer()
			status = .active(next: nil)
			return
		}

		// A manual override parks automation until the next natural transition.
		if let overrideUntil {
			if now < overrideUntil {
				status = .pausedByOverride(until: overrideUntil)
				armTransitionTimer(for: overrideUntil)
				return
			}
			self.overrideUntil = nil  // expired -> resume automation below
		}

		if plan.desired != currentAppearance {
			apply(plan.desired)
			Log.scheduler.info("Applied \(plan.desired.rawValue, privacy: .public) appearance")
		}
		status = .active(next: plan.nextTransition)
		armTransitionTimer(for: plan.nextTransition)
	}

	/// Flips the appearance immediately. If automation is live, parks it until the next natural transition
	/// (never disables it permanently); otherwise just leaves the manual flip in place.
	func toggleAppearanceNow() {
		currentAppearance = appearance.current()
		let target = currentAppearance.toggled
		apply(target)
		Log.scheduler.info("Manual toggle to \(target.rawValue, privacy: .public)")

		guard settings.isEnabled, let coordinate = effectiveCoordinate,
			let plan = currentPlan(at: Date(), coordinate: coordinate),
			let next = plan.nextTransition
		else { return }

		overrideUntil = next
		status = .pausedByOverride(until: next)
		armTransitionTimer(for: next)
	}

	// MARK: - Internals

	private func currentPlan(at now: Date, coordinate: CLLocationCoordinate2D) -> AppearancePlan? {
		TransitionPlanner.plan(
			at: now,
			latitude: coordinate.latitude,
			longitude: coordinate.longitude,
			sunriseOffsetMinutes: settings.sunriseOffsetMinutes,
			sunsetOffsetMinutes: settings.sunsetOffsetMinutes
		)
	}

	private func apply(_ target: Appearance) {
		appearance.set(target)
		// Trust the value just applied: the AppleInterfaceStyle default updates asynchronously, so an
		// immediate read-back would still return the OLD value and leave the menu-bar glyph stale for
		// hours. The distributed theme-change notification re-syncs from the system afterwards.
		currentAppearance = target
	}

	private func handleSettingsChange() {
		syncLocationMode()
		refresh()
	}

	private func handleWake() {
		// The Mac may have moved while asleep; ask for a fresh one-shot fix before recomputing.
		if settings.locationMode == .automatic {
			location.requestFix()
		}
		refresh()
	}

	private func syncLocationMode() {
		if settings.locationMode == .manual {
			location.stop()
		} else {
			location.start()
		}
	}

	private func observe(
		_ center: NotificationCenter,
		name: Notification.Name,
		handler: @escaping @MainActor () -> Void
	) {
		let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
			MainActor.assumeIsolated {
				handler()
			}
		}
		notificationTokens.append(token)
	}

	private func armTransitionTimer(for date: Date?) {
		cancelTransitionTimer()
		guard let date else { return }

		// Fire one second past the boundary so the recompute lands unambiguously on the far side.
		let fireDate = date.addingTimeInterval(1)
		guard fireDate > Date() else { return }

		let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
			MainActor.assumeIsolated {
				self?.refresh()
			}
		}
		timer.tolerance = 5
		RunLoop.main.add(timer, forMode: .common)
		transitionTimer = timer
	}

	private func cancelTransitionTimer() {
		transitionTimer?.invalidate()
		transitionTimer = nil
	}
}
