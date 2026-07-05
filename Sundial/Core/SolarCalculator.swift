//
//  SolarCalculator.swift
//  Sundial
//
//  Self-contained NOAA low-precision sunrise/sunset calculator (no network, no Foundation astronomy APIs).
//

import Foundation

/// Computes sunrise and sunset for a coordinate and civil day using the standard NOAA solar position
/// algorithm with the official-zenith of 90.833 degrees (accounts for refraction and the solar radius).
///
/// The events returned are the ones on the civil day that contains `date` in `timeZone`. Days where the
/// sun never crosses the horizon are reported as `.polarDay` / `.polarNight`.
nonisolated enum SolarCalculator {
	/// What the sun does over one civil day at a coordinate.
	enum Daylight: Equatable {
		case sunriseSunset(sunrise: Date, sunset: Date)
		case polarDay  // the sun never sets
		case polarNight  // the sun never rises
	}

	/// The apparent zenith at sunrise/sunset: 90 degrees plus 50 arc-minutes for refraction and solar radius.
	private static let sunriseSunsetZenith = 90.833

	static func sunrise(
		on date: Date,
		latitude: Double,
		longitude: Double,
		timeZone: TimeZone = .current
	) -> Date? {
		guard
			case .sunriseSunset(let sunrise, _) = daylight(
				on: date, latitude: latitude, longitude: longitude, timeZone: timeZone)
		else { return nil }
		return sunrise
	}

	static func sunset(
		on date: Date,
		latitude: Double,
		longitude: Double,
		timeZone: TimeZone = .current
	) -> Date? {
		guard
			case .sunriseSunset(_, let sunset) = daylight(
				on: date, latitude: latitude, longitude: longitude, timeZone: timeZone)
		else { return nil }
		return sunset
	}

	// MARK: - Core algorithm

	/// Full description of the civil day; `nil` only when calendar arithmetic fails.
	static func daylight(
		on date: Date,
		latitude: Double,
		longitude: Double,
		timeZone: TimeZone = .current
	) -> Daylight? {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = timeZone

		// Anchor the computation at local civil noon of the target day; the slow-moving solar quantities
		// (declination, equation of time) are evaluated once at that instant.
		var noonComponents = calendar.dateComponents([.year, .month, .day], from: date)
		noonComponents.hour = 12
		noonComponents.minute = 0
		noonComponents.second = 0
		guard let localNoon = calendar.date(from: noonComponents) else { return nil }

		// Julian day / century from the UTC representation of local civil noon.
		let julianDay = localNoon.timeIntervalSince1970 / 86_400 + 2_440_587.5
		let julianCentury = (julianDay - 2_451_545.0) / 36_525.0

		// Sun's geometric mean longitude and mean anomaly (degrees), orbital eccentricity.
		let geomMeanLongitude = 280.46646 + julianCentury * (36_000.76983 + julianCentury * 0.0003032)
		let geomMeanAnomaly = 357.52911 + julianCentury * (35_999.05029 - julianCentury * 0.0001537)
		let eccentricity = 0.016708634 - julianCentury * (0.000042037 + julianCentury * 0.0000001267)

		// Equation of the centre corrects the mean anomaly to the true anomaly.
		let equationOfCenter =
			sin(radians(geomMeanAnomaly)) * (1.914602 - julianCentury * (0.004817 + julianCentury * 0.000014))
			+ sin(radians(2 * geomMeanAnomaly)) * (0.019993 - julianCentury * 0.000101)
			+ sin(radians(3 * geomMeanAnomaly)) * 0.000289
		let trueLongitude = geomMeanLongitude + equationOfCenter
		let apparentLongitude =
			trueLongitude - 0.00569 - 0.00478 * sin(radians(125.04 - 1934.136 * julianCentury))

		// Obliquity of the ecliptic (degrees, minutes, seconds form), corrected for nutation.
		let obliquitySeconds = 21.448 - julianCentury * (46.815 + julianCentury * (0.00059 - julianCentury * 0.001813))
		let meanObliquity = 23 + (26 + obliquitySeconds / 60) / 60
		let obliquity = meanObliquity + 0.00256 * cos(radians(125.04 - 1934.136 * julianCentury))

		let solarDeclination = degrees(asin(sin(radians(obliquity)) * sin(radians(apparentLongitude))))

		// Equation of time (minutes): the gap between apparent and mean solar time.
		let obliquityTerm = pow(tan(radians(obliquity / 2)), 2)
		let equationOfTime =
			4
			* degrees(
				obliquityTerm * sin(2 * radians(geomMeanLongitude))
					- 2 * eccentricity * sin(radians(geomMeanAnomaly))
					+ 4 * eccentricity * obliquityTerm * sin(radians(geomMeanAnomaly))
					* cos(2 * radians(geomMeanLongitude))
					- 0.5 * obliquityTerm * obliquityTerm * sin(4 * radians(geomMeanLongitude))
					- 1.25 * eccentricity * eccentricity * sin(2 * radians(geomMeanAnomaly))
			)

		// Hour angle from solar noon to the event. Out of [-1, 1] means the sun never reaches the
		// horizon that day: below it all day (> 1, polar night) or above it all day (< -1, polar day).
		let cosHourAngle =
			(cos(radians(sunriseSunsetZenith)) - sin(radians(latitude)) * sin(radians(solarDeclination)))
			/ (cos(radians(latitude)) * cos(radians(solarDeclination)))
		if cosHourAngle > 1 { return .polarNight }
		if cosHourAngle < -1 { return .polarDay }
		let hourAngle = degrees(acos(cosHourAngle))

		// Convert to absolute instants relative to local noon. Time flows 1:1 with true solar time,
		// so the offset from local clock noon to solar noon is (timeZoneOffset - longitude/15 - EoT/60).
		let timeZoneOffsetHours = Double(timeZone.secondsFromGMT(for: localNoon)) / 3600
		let solarNoonOffsetHours = timeZoneOffsetHours - longitude / 15 - equationOfTime / 60

		return .sunriseSunset(
			sunrise: localNoon.addingTimeInterval((solarNoonOffsetHours - hourAngle / 15) * 3600),
			sunset: localNoon.addingTimeInterval((solarNoonOffsetHours + hourAngle / 15) * 3600)
		)
	}

	private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
	private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
