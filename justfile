# Gloaming macOS App - Development Commands

# Default recipe: list available commands
default:
    @just --list

# Format all Swift files
format:
    swift format --in-place --recursive Gloaming/ GloamingTests/

# Lint Swift files (check without modifying)
lint:
    swift format lint --strict --recursive Gloaming/ GloamingTests/
    swiftlint --quiet --strict

# Build (debug)
build:
    xcodebuild build -project Gloaming.xcodeproj -scheme Gloaming -configuration Debug -destination 'platform=macOS' | xcbeautify || xcodebuild build -project Gloaming.xcodeproj -scheme Gloaming -configuration Debug -destination 'platform=macOS'

# Build for release
build-release:
    xcodebuild build -project Gloaming.xcodeproj -scheme Gloaming -configuration Release -destination 'platform=macOS'

# Run unit tests
test:
    xcodebuild test -project Gloaming.xcodeproj -scheme Gloaming -destination 'platform=macOS'

# Clean build artifacts
clean:
    xcodebuild clean -project Gloaming.xcodeproj -scheme Gloaming

# Open project in Xcode
open:
    open Gloaming.xcodeproj

# Build SPM package for VS Code LSP support
lsp:
    swift build

# Regenerate the AppIcon PNGs from the icon script
icon:
    swift scripts/generate-appicon.swift Gloaming/Assets.xcassets/AppIcon.appiconset

# Format, build, and test
check: format build test
