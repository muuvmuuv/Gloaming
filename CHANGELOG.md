# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release notes on [GitHub Releases](../../releases) are generated from commit history at tag time
(see `.github/workflows/release.yml`); this file tracks the same history for anyone reading the
repo directly.

## [Unreleased]

## [1.0.0] - 2026-07-06

### Added

- Initial implementation: menu-bar app that switches system-wide Light/Dark appearance from
  on-device sunrise/sunset (NOAA solar algorithm) with configurable minute offsets.
- Automatic (CoreLocation, city-level) or manual latitude/longitude location.
- Manual "toggle appearance now" override that pauses automation until the next natural
  transition.
- Launch at login via `SMAppService`.
- Developer ID signing, notarization, and DMG release pipeline via GitHub Actions.
