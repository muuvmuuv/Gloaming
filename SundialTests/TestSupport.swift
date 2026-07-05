//
//  TestSupport.swift
//  SundialTests
//
//  Shared helpers for the unit-test suites.
//

import Foundation

/// Builds an exact `Date` in an explicit time zone; tests never rely on the machine's zone.
func makeDate(
	_ year: Int,
	_ month: Int,
	_ day: Int,
	hour: Int = 0,
	minute: Int = 0,
	timeZone: TimeZone
) -> Date {
	var calendar = Calendar(identifier: .gregorian)
	calendar.timeZone = timeZone
	let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
	return calendar.date(from: components)!
}
