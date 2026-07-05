//
//  TransitionPlannerTests.swift
//  GloamingTests
//
//  Window / offset / boundary semantics for the pure transition planner.
//

import Foundation
import Testing

@testable import Gloaming

@Suite struct TransitionPlannerTests {
	// Berlin.
	private let latitude = 52.52
	private let longitude = 13.405
	private let berlin = TimeZone(identifier: "Europe/Berlin")!

	@Test func noonIsLightUntilSunset() throws {
		let now = makeDate(2026, 6, 21, hour: 12, timeZone: berlin)
		let plan = try #require(
			TransitionPlanner.plan(
				at: now, latitude: latitude, longitude: longitude,
				sunriseOffsetMinutes: 0, sunsetOffsetMinutes: 0, timeZone: berlin
			)
		)
		#expect(plan.desired == .light)

		let expectedSunset = makeDate(2026, 6, 21, hour: 21, minute: 33, timeZone: berlin)
		let nextTransition = try #require(plan.nextTransition)
		#expect(abs(nextTransition.timeIntervalSince(expectedSunset)) <= 6 * 60)
	}

	@Test func lateEveningIsDarkUntilTomorrowSunrise() throws {
		let now = makeDate(2026, 6, 21, hour: 23, timeZone: berlin)
		let plan = try #require(
			TransitionPlanner.plan(
				at: now, latitude: latitude, longitude: longitude,
				sunriseOffsetMinutes: 0, sunsetOffsetMinutes: 0, timeZone: berlin
			)
		)
		#expect(plan.desired == .dark)

		let tomorrow = makeDate(2026, 6, 22, timeZone: berlin)
		let expectedSunrise = try #require(
			SolarCalculator.sunrise(on: tomorrow, latitude: latitude, longitude: longitude, timeZone: berlin)
		)
		#expect(plan.nextTransition == expectedSunrise)
	}

	@Test func sunriseOffsetShiftsMorningBoundaryExactly() throws {
		// A pre-dawn moment so the next boundary is the morning start for both plans.
		let now = makeDate(2026, 6, 21, hour: 2, timeZone: berlin)
		let base = try #require(
			TransitionPlanner.plan(
				at: now, latitude: latitude, longitude: longitude,
				sunriseOffsetMinutes: 0, sunsetOffsetMinutes: 0, timeZone: berlin
			)
		)
		let shifted = try #require(
			TransitionPlanner.plan(
				at: now, latitude: latitude, longitude: longitude,
				sunriseOffsetMinutes: 60, sunsetOffsetMinutes: 0, timeZone: berlin
			)
		)
		let baseBoundary = try #require(base.nextTransition)
		let shiftedBoundary = try #require(shifted.nextTransition)
		#expect(shiftedBoundary.timeIntervalSince(baseBoundary) == 3600)
	}

	@Test func negativeSunriseOffsetExtendsLightBeforeDawn() throws {
		// June sunrise ~04:43; -240 min pulls the light window start back to ~00:43, so 03:00 is light.
		let now = makeDate(2026, 6, 21, hour: 3, timeZone: berlin)
		let plan = try #require(
			TransitionPlanner.plan(
				at: now, latitude: latitude, longitude: longitude,
				sunriseOffsetMinutes: -240, sunsetOffsetMinutes: 0, timeZone: berlin
			)
		)
		#expect(plan.desired == .light)
	}

	@Test func extremeOffsetsEmptyTheWindow() throws {
		// A short high-latitude winter day (Oslo) squeezed to nothing by +/-240 minute offsets -> all dark.
		let oslo = TimeZone(identifier: "Europe/Oslo")!
		let now = makeDate(2026, 12, 21, hour: 12, timeZone: oslo)
		let plan = try #require(
			TransitionPlanner.plan(
				at: now, latitude: 59.91, longitude: 10.75,
				sunriseOffsetMinutes: 240, sunsetOffsetMinutes: -240, timeZone: oslo
			)
		)
		#expect(plan.desired == .dark)
	}

	@Test func polarNightIsDark() throws {
		let oslo = TimeZone(identifier: "Europe/Oslo")!
		let now = makeDate(2026, 12, 21, hour: 12, timeZone: oslo)
		let plan = try #require(
			TransitionPlanner.plan(
				at: now, latitude: 69.65, longitude: 18.96,
				sunriseOffsetMinutes: 0, sunsetOffsetMinutes: 0, timeZone: oslo
			)
		)
		#expect(plan.desired == .dark)
		#expect(plan.nextTransition == nil)  // no light window within the evaluated days
	}

	@Test func deepMidnightSunIsLight() throws {
		let oslo = TimeZone(identifier: "Europe/Oslo")!
		let now = makeDate(2026, 6, 21, hour: 12, timeZone: oslo)
		let plan = try #require(
			TransitionPlanner.plan(
				at: now, latitude: 69.65, longitude: 18.96,
				sunriseOffsetMinutes: 0, sunsetOffsetMinutes: 0, timeZone: oslo
			)
		)
		#expect(plan.desired == .light)
		// Consecutive polar-day windows abut at midnight, so the next boundary is tonight's midnight.
		#expect(plan.nextTransition == makeDate(2026, 6, 22, timeZone: oslo))
	}

	@Test func midnightSunBoundaryDaysAreLight() throws {
		// Tromsø 2026: 05-18 is the first civil day the sun no longer sets, 07-25 the last. On these days
		// a neighboring day still computes sunrise/sunset, which used to force the plan to .dark.
		let oslo = TimeZone(identifier: "Europe/Oslo")!
		for (month, day) in [(5, 18), (7, 25)] {
			let now = makeDate(2026, month, day, hour: 12, timeZone: oslo)
			let plan = try #require(
				TransitionPlanner.plan(
					at: now, latitude: 69.65, longitude: 18.96,
					sunriseOffsetMinutes: 0, sunsetOffsetMinutes: 0, timeZone: oslo
				)
			)
			#expect(plan.desired == .light)
		}
	}
}
