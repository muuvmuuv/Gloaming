//
//  LocationProvider.swift
//  Gloaming
//
//  CoreLocation wrapper: one-shot fix + significant-change monitoring, with a cached last fix.
//

import CoreLocation
import Foundation
import OSLog

/// Provides the Mac's approximate location for solar calculations.
///
/// Uses reduced accuracy (city level is plenty), a one-shot fix on start, and significant-change
/// monitoring thereafter. The last fix is cached in `UserDefaults` and restored on launch so a fresh
/// start has a usable coordinate before CoreLocation delivers the first live update.
@Observable final class LocationProvider {
	private(set) var coordinate: CLLocationCoordinate2D?
	private(set) var isAuthorizationDenied = false

	/// Set by the `Scheduler`; invoked when a new fix or authorization change arrives.
	@ObservationIgnored var onUpdate: (() -> Void)?

	@ObservationIgnored private let defaults: UserDefaults
	// Created lazily in start() so init stays side-effect free (no permission prompt from tests).
	@ObservationIgnored private var manager: CLLocationManager?
	@ObservationIgnored private var delegateProxy: DelegateProxy?

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
		if defaults.object(forKey: "lastLatitude") != nil, defaults.object(forKey: "lastLongitude") != nil {
			coordinate = CLLocationCoordinate2D(
				latitude: defaults.double(forKey: "lastLatitude"),
				longitude: defaults.double(forKey: "lastLongitude")
			)
		}
	}

	func start() {
		let manager = ensureManager()
		manager.startMonitoringSignificantLocationChanges()
		evaluateAuthorization(of: manager)
	}

	func requestFix() {
		guard let manager else { return }
		switch manager.authorizationStatus {
		case .authorizedAlways, .authorized:
			manager.requestLocation()
		default:
			break
		}
	}

	func stop() {
		manager?.stopMonitoringSignificantLocationChanges()
	}

	// MARK: - Internals

	private func ensureManager() -> CLLocationManager {
		if let manager {
			return manager
		}
		let manager = CLLocationManager()
		let proxy = DelegateProxy(provider: self)
		manager.delegate = proxy
		manager.desiredAccuracy = kCLLocationAccuracyReduced
		self.manager = manager
		delegateProxy = proxy
		return manager
	}

	private func evaluateAuthorization(of manager: CLLocationManager) {
		switch manager.authorizationStatus {
		case .authorizedAlways, .authorized:
			isAuthorizationDenied = false
			manager.requestLocation()
		case .denied, .restricted:
			isAuthorizationDenied = true
		case .notDetermined:
			isAuthorizationDenied = false
			manager.requestWhenInUseAuthorization()
		@unknown default:
			break
		}
	}

	private func handleFix(_ coordinate: CLLocationCoordinate2D) {
		self.coordinate = coordinate
		isAuthorizationDenied = false
		defaults.set(coordinate.latitude, forKey: "lastLatitude")
		defaults.set(coordinate.longitude, forKey: "lastLongitude")
		onUpdate?()
	}

	private func handleAuthorizationChange() {
		guard let manager else { return }
		evaluateAuthorization(of: manager)
		onUpdate?()
	}

	/// Bridges CoreLocation's callbacks (delivered off the main actor) back onto the `LocationProvider`.
	private nonisolated final class DelegateProxy: NSObject, CLLocationManagerDelegate {
		weak var provider: LocationProvider?

		init(provider: LocationProvider) {
			self.provider = provider
		}

		func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
			guard let coordinate = locations.last?.coordinate else { return }
			let provider = provider
			Task { @MainActor in
				provider?.handleFix(coordinate)
			}
		}

		func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
			Log.location.error("Location update failed: \(error.localizedDescription, privacy: .public)")
		}

		func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
			let provider = provider
			Task { @MainActor in
				provider?.handleAuthorizationChange()
			}
		}
	}
}
