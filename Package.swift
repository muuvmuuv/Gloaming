// swift-tools-version:6.2
// This Package.swift is for SourceKit-LSP support only (VS Code etc.).
// Build and run using Xcode/xcodebuild with Sundial.xcodeproj.

import PackageDescription

let package = Package(
	name: "Sundial",
	platforms: [
		.macOS(.v14)
	],
	products: [
		.library(name: "Sundial", targets: ["Sundial"])
	],
	targets: [
		.target(
			name: "Sundial",
			path: "Sundial",
			exclude: ["Assets.xcassets", "Sundial.entitlements"],
			swiftSettings: [
				// Mirror the Xcode project: approachable concurrency, MainActor by default.
				.defaultIsolation(MainActor.self),
				.enableUpcomingFeature("MemberImportVisibility"),
			]
		)
	]
)
