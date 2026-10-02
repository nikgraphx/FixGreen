# Fix Green

Fix Green is a free, native macOS menu bar app that turns the green window button into a quick zoom-and-restore control. It keeps the Dock and menu bar available, and adds a few useful controls around the behavior.

<p align="center">
  <img src="OpenRightZoom/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" width="180" alt="Fix Green app icon">
</p>

## Features

- Click a window's green button to fill the usable screen area; click again to restore its previous size.
- Keep the Dock and menu bar clear. Fix Green uses the display's visible area.
- Optionally leave an 8-point gutter around zoomed windows. This is enabled by default for new installs and can be changed in Settings.
- Hold a modifier while clicking the green button to keep the standard macOS fullscreen behavior.
- Zoom the active window with **Control–Shift–Z**, or use **Zoom Active Window** and **Restore Previous Size** in the menu bar menu.
- Choose whether Fix Green launches at login.
- Follow first-run guidance for the macOS Accessibility permission needed to control other apps' windows.

## Download and install

1. Open [Releases](https://github.com/nikgraphx/FixGreen/releases) and download the latest `Fix-Green-*.zip`.
2. Open the ZIP and move `Fix Green.app` to **Applications**.
3. Launch Fix Green. If macOS blocks an unsigned download, Control-click the app and choose **Open**.
4. In Fix Green's onboarding or Settings, choose **Open Settings**. In **System Settings → Privacy & Security → Accessibility**, use **+** to add `/Applications/Fix Green.app`, then turn it on.
5. Return to Fix Green. The permission status refreshes automatically. If you replace the app with a newer ad-hoc-signed build, macOS may require you to remove the old Accessibility entry and add the new app again.

macOS requires the user to add and enable Accessibility access; apps cannot grant this permission to themselves. Add the copy from **Applications** after moving it there.

## Privacy

Fix Green works locally. It does not require an account, collect analytics, or send window contents over the network. Accessibility access lets the app detect the green window button and read or change the target window's position and size. A global event tap detects clicks on that button; the optional shortcut uses a global keyboard event monitor.

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac

## Build from source

Install Xcode, then clone and open the project:

```sh
git clone https://github.com/nikgraphx/FixGreen.git
cd FixGreen
open OpenRightZoom.xcodeproj
```

In Xcode, select the `OpenRightZoom` scheme and run it. To build a universal Release app from Terminal:

```sh
xcodebuild \
  -project OpenRightZoom.xcodeproj \
  -scheme OpenRightZoom \
  -configuration Release \
  -destination 'platform=macOS' \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  build
```

## Releases

The GitHub Actions workflow builds a universal app, creates a ZIP, and publishes a GitHub Release when a matching version tag is pushed. Before releasing, update `CFBundleShortVersionString` and `CFBundleVersion` in `OpenRightZoom/Info.plist`, then push a tag such as `v1.0.1`:

```sh
git tag v1.0.1
git push origin v1.0.1
```

The automated build is ad-hoc signed so people can try it, but it is not notarized. Public distribution without the first-launch security warning requires a Developer ID signature and notarization with Apple. The repository does not contain signing credentials; see [Apple's notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Origin and license

Fix Green began as a fork of **[Open Right Zoom](https://github.com/Michele0303/open-right-zoom)** by Michele0303. It keeps the original window-zooming idea and adds configurable screen margins, a native settings and onboarding experience, Accessibility guidance, menu bar actions, and a keyboard shortcut. Thank you to the original author and contributors. The upstream MIT license is preserved in [LICENSE](LICENSE).

## Contributing

Issues and pull requests are welcome. Please include your macOS version and steps to reproduce window-management issues.
