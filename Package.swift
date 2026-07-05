// swift-tools-version:6.2
// This Package.swift is for SourceKit-LSP support only (VS Code etc.).
// Build and run using Xcode/xcodebuild with Gloaming.xcodeproj.

import PackageDescription

let package = Package(
	name: "Gloaming",
	platforms: [
		.macOS(.v14)
	],
	products: [
		.library(name: "Gloaming", targets: ["Gloaming"])
	],
	targets: [
		.target(
			name: "Gloaming",
			path: "Gloaming",
			exclude: ["Assets.xcassets", "Gloaming.entitlements"],
			swiftSettings: [
				// Mirror the Xcode project: approachable concurrency, MainActor by default.
				.defaultIsolation(MainActor.self),
				.enableUpcomingFeature("MemberImportVisibility"),
			]
		)
	]
)
