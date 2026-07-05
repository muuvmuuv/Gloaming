# Sundial macOS App - Development Commands

# Default recipe: list available commands
default:
    @just --list

# Format all Swift files
format:
    swift format --in-place --recursive Sundial/ SundialTests/

# Lint Swift files (check without modifying)
lint:
    swift format lint --strict --recursive Sundial/ SundialTests/
    swiftlint --quiet --strict

# Build (debug)
build:
    xcodebuild build -project Sundial.xcodeproj -scheme Sundial -configuration Debug -destination 'platform=macOS' | xcbeautify || xcodebuild build -project Sundial.xcodeproj -scheme Sundial -configuration Debug -destination 'platform=macOS'

# Build for release
build-release:
    xcodebuild build -project Sundial.xcodeproj -scheme Sundial -configuration Release -destination 'platform=macOS'

# Run unit tests
test:
    xcodebuild test -project Sundial.xcodeproj -scheme Sundial -destination 'platform=macOS'

# Clean build artifacts
clean:
    xcodebuild clean -project Sundial.xcodeproj -scheme Sundial

# Open project in Xcode
open:
    open Sundial.xcodeproj

# Build SPM package for VS Code LSP support
lsp:
    swift build

# Regenerate the AppIcon PNGs from the icon script
icon:
    swift scripts/generate-appicon.swift Sundial/Assets.xcassets/AppIcon.appiconset

# Format, build, and test
check: format build test
