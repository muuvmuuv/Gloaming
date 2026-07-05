//
//  SolarCalculatorTests.swift
//  SundialTests
//
//  Known-coordinate sunrise/sunset checks and polar edge cases for the NOAA calculator.
//

import Foundation
import Testing

@testable import Sundial

private let sixMinutes: TimeInterval = 6 * 60

@Suite struct SolarCalculatorTests {
	@Test func berlinMidsummer() throws {
		let timeZone = TimeZone(identifier: "Europe/Berlin")!
		let day = makeDate(2026, 6, 21, timeZone: timeZone)
		let sunrise = try #require(
			SolarCalculator.sunrise(on: day, latitude: 52.52, longitude: 13.405, timeZone: timeZone)
		)
		let sunset = try #require(
			SolarCalculator.sunset(on: day, latitude: 52.52, longitude: 13.405, timeZone: timeZone)
		)

		let expectedSunrise = makeDate(2026, 6, 21, hour: 4, minute: 43, timeZone: timeZone)
		let expectedSunset = makeDate(2026, 6, 21, hour: 21, minute: 33, timeZone: timeZone)
		#expect(abs(sunrise.timeIntervalSince(expectedSunrise)) <= sixMinutes)
		#expect(abs(sunset.timeIntervalSince(expectedSunset)) <= sixMinutes)
	}

	@Test func sydneyMidwinter() throws {
		let timeZone = TimeZone(identifier: "Australia/Sydney")!
		let day = makeDate(2026, 6, 21, timeZone: timeZone)
		let sunrise = try #require(
			SolarCalculator.sunrise(on: day, latitude: -33.87, longitude: 151.21, timeZone: timeZone)
		)
		let sunset = try #require(
			SolarCalculator.sunset(on: day, latitude: -33.87, longitude: 151.21, timeZone: timeZone)
		)

		let expectedSunrise = makeDate(2026, 6, 21, hour: 7, minute: 1, timeZone: timeZone)
		let expectedSunset = makeDate(2026, 6, 21, hour: 16, minute: 54, timeZone: timeZone)
		#expect(abs(sunrise.timeIntervalSince(expectedSunrise)) <= sixMinutes)
		#expect(abs(sunset.timeIntervalSince(expectedSunset)) <= sixMinutes)
	}

	@Test func quitoDayLengthNearTwelveHours() throws {
		let timeZone = TimeZone(identifier: "America/Guayaquil")!
		let latitude = -0.18
		let longitude = -78.47
		let twelveHours: TimeInterval = 12 * 3600
		let tolerance: TimeInterval = 20 * 60

		for day in [makeDate(2026, 6, 21, timeZone: timeZone), makeDate(2026, 12, 21, timeZone: timeZone)] {
			let sunrise = try #require(
				SolarCalculator.sunrise(on: day, latitude: latitude, longitude: longitude, timeZone: timeZone)
			)
			let sunset = try #require(
				SolarCalculator.sunset(on: day, latitude: latitude, longitude: longitude, timeZone: timeZone)
			)
			let dayLength = sunset.timeIntervalSince(sunrise)
			#expect(abs(dayLength - twelveHours) <= tolerance)
		}
	}

	@Test func tromsoPolarNightAndMidnightSun() {
		let timeZone = TimeZone(identifier: "Europe/Oslo")!
		let latitude = 69.65
		let longitude = 18.96

		for day in [makeDate(2026, 12, 21, timeZone: timeZone), makeDate(2026, 6, 21, timeZone: timeZone)] {
			let sunrise = SolarCalculator.sunrise(on: day, latitude: latitude, longitude: longitude, timeZone: timeZone)
			let sunset = SolarCalculator.sunset(on: day, latitude: latitude, longitude: longitude, timeZone: timeZone)
			#expect(sunrise == nil)
			#expect(sunset == nil)
		}

		// daylight(on:) tells the two polar cases apart — the planner depends on this distinction.
		let december = makeDate(2026, 12, 21, timeZone: timeZone)
		let june = makeDate(2026, 6, 21, timeZone: timeZone)
		#expect(
			SolarCalculator.daylight(on: december, latitude: latitude, longitude: longitude, timeZone: timeZone)
				== .polarNight
		)
		#expect(
			SolarCalculator.daylight(on: june, latitude: latitude, longitude: longitude, timeZone: timeZone)
				== .polarDay
		)
	}

	@Test func sunriseIsAlwaysBeforeSunset() throws {
		let timeZone = TimeZone(identifier: "Europe/Berlin")!
		let days = [
			makeDate(2026, 3, 15, timeZone: timeZone),
			makeDate(2026, 6, 21, timeZone: timeZone),
			makeDate(2026, 9, 15, timeZone: timeZone),
			makeDate(2026, 11, 1, timeZone: timeZone),
		]
		for day in days {
			let sunrise = try #require(
				SolarCalculator.sunrise(on: day, latitude: 52.52, longitude: 13.405, timeZone: timeZone)
			)
			let sunset = try #require(
				SolarCalculator.sunset(on: day, latitude: 52.52, longitude: 13.405, timeZone: timeZone)
			)
			#expect(sunrise < sunset)
		}
	}
}
