# Fix Green

Fix Green is a small, native macOS menu bar utility that makes the green window button zoom the active window while keeping the menu bar and Dock available. It also lets you restore the window's previous size with another click.

## Features

- Zoom the active window to the usable screen area, with an optional 8-point margin.
- Keep the menu bar and Dock clear by using the display's visible area.
- Restore the last window's previous size from the menu bar.
- Use **Control–Shift–Z** to zoom the active window.
- Keep standard macOS fullscreen behavior by holding a modifier while clicking the green button.
- Configure window behavior and launch at login in a native settings window.
- First-launch onboarding explains the required Accessibility permission.

The margin option is on by default for new installs. Fix Green uses Accessibility access to detect and resize other apps' windows; it does not send window contents anywhere.

## Install

Download the latest `Fix Green` app from the [GitHub Releases page](https://github.com/nikgraphx/FixGreen/releases), move it to `/Applications`, and launch it. Open **System Settings → Privacy & Security → Accessibility**, unlock the settings if needed, and enable Fix Green. If it is not listed, use **+** to add `/Applications/Fix Green.app`.

Releases built without an Apple Developer ID may show a first-launch security warning. For a local build, open the app with Control-click → **Open**. For public releases that install without this warning, sign the app with a Developer ID certificate and notarize it with Apple before publishing.

## Build from source

Requirements: macOS 13 or later and Xcode.

```sh
git clone https://github.com/nikgraphx/FixGreen.git
cd FixGreen
open OpenRightZoom.xcodeproj
```

Select the `OpenRightZoom` scheme and run it from Xcode. To build a Release app from Terminal:

```sh
xcodebuild -project OpenRightZoom.xcodeproj \
  -scheme OpenRightZoom \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

## Publishing a release

The GitHub Actions workflow builds and attaches a ZIP whenever a version tag such as `v1.1.0` is pushed:

```sh
git tag v1.1.0
git push origin v1.1.0
```

The workflow creates a GitHub Release with generated notes and the `Fix Green` app. It applies an ad-hoc signature so the app can be tried, but that is not Apple notarization. A public release without the first-launch security warning needs a Developer ID Application certificate and Apple notarization; those credentials must be configured as GitHub Actions secrets before changing the workflow to sign and notarize.

## License

MIT. See [LICENSE](LICENSE).
