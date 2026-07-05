//
//  TransitionPlanner.swift
//  Sundial
//
//  Pure decision layer: turns sun times + offsets into a desired appearance and the next boundary.
//

import Foundation

/// The outcome of evaluating the schedule at a moment in time.
nonisolated struct AppearancePlan: Equatable, Sendable {
	/// The appearance that should be active right now.
	var desired: Appearance
	/// The earliest upcoming boundary at which `desired` flips, or `nil` when no future boundary is
	/// computable (deep polar) — the caller then holds the current appearance and re-checks on day change.
	var nextTransition: Date?
}

nonisolated enum TransitionPlanner {
	/// Evaluates the light/dark schedule at `now`.
	///
	/// The light window for a given day is `[sunrise + sunriseOffset, sunset + sunsetOffset)`. Windows
	/// where the end is not after the start (offsets that swallow the whole day) are discarded as all-dark.
	/// A polar day (midnight sun) counts as one light window spanning the whole civil day; a polar night
	/// contributes no window. Returns `nil` only when no day could be evaluated at all (calendar failure).
	static func plan(
		at now: Date,
		latitude: Double,
		longitude: Double,
		sunriseOffsetMinutes: Int,
		sunsetOffsetMinutes: Int,
		timeZone: TimeZone = .current
	) -> AppearancePlan? {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = timeZone

		var anyDayEvaluated = false
		var boundaries: [Date] = []
		var isLight = false

		// Evaluate yesterday, today and tomorrow so windows whose offsets cross midnight are captured
		// no matter which side of a boundary `now` sits on.
		for dayOffset in -1...1 {
			guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
				let daylight = SolarCalculator.daylight(
					on: day, latitude: latitude, longitude: longitude, timeZone: timeZone
				)
			else { continue }
			anyDayEvaluated = true

			let windowStart: Date
			let windowEnd: Date
			switch daylight {
			case .polarNight:
				continue  // no light window this day

			case .polarDay:
				// Offsets are meaningless without sunrise/sunset; treat the whole civil day as light.
				windowStart = calendar.startOfDay(for: day)
				guard let nextDay = calendar.date(byAdding: .day, value: 1, to: windowStart) else { continue }
				windowEnd = nextDay

			case .sunriseSunset(let sunrise, let sunset):
				windowStart = sunrise.addingTimeInterval(Double(sunriseOffsetMinutes) * 60)
				windowEnd = sunset.addingTimeInterval(Double(sunsetOffsetMinutes) * 60)
			}
			guard windowEnd > windowStart else { continue }  // offsets emptied the day -> all dark

			boundaries.append(windowStart)
			boundaries.append(windowEnd)
			if now >= windowStart, now < windowEnd { isLight = true }
		}

		guard anyDayEvaluated else { return nil }

		let nextTransition = boundaries.filter { $0 > now }.min()
		return AppearancePlan(desired: isLight ? .light : .dark, nextTransition: nextTransition)
	}
}
