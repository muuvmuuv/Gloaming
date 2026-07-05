//
//  Appearance.swift
//  Sundial
//
//  The two system-wide appearances Sundial switches between.
//

/// A system appearance mode. Raw values match the persisted / logged spelling.
nonisolated enum Appearance: String, Sendable {
	case light
	case dark

	/// The opposite appearance, used by the manual "toggle now" action.
	var toggled: Appearance {
		self == .light ? .dark : .light
	}
}
