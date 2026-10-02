# Changelog

Changes to Fix Green releases are collected here.

## [1.0.3] - 2026-10-03

### Fixed

- Corrected window placement to use the active display's current usable frame and verify the final Accessibility frame. The lower edge now gets extra clearance when a side or auto-hidden Dock leaves it exposed, while a bottom Dock keeps the normal gutter.
- Stopped invoking macOS's native green-button zoom action while handling a Fix Green click, avoiding the full-screen regression and helping the native tiling preview dismiss when the click is intercepted.
- Removed the extra Accessibility prompt that could appear while System Settings was already opening.

### Added

- Added a **Check for Updates** menu item. The app checks only when asked, then opens the matching GitHub release page if a newer version is available.
- Added an in-app reminder to remove and re-add Fix Green in Accessibility if window control stops after an update.
- Added a release workflow that builds a universal app, attaches the app ZIP to a draft GitHub Release, then publishes it. Release notes now come from this changelog.

### Repository

- Removed personal Xcode user-state files from the project and corrected the security contact information.
