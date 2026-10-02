# Fix Green

Fix Green is a small macOS utility for people who want the green window button to zoom a window into the usable screen area instead of sending it to a separate full-screen space. Click the green button again to restore the window.

The project started as a fork of [Open Right Zoom](https://github.com/Michele0303/open-right-zoom) by Michele0303. Fix Green keeps that original idea and adds configurable screen margins, settings and first-run Accessibility guidance, menu-bar controls, and keyboard shortcuts.

<p align="center">
  <img src="OpenRightZoom/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" width="180" alt="Fix Green app icon">
</p>

## What it does

- Click the green window button to fill the display's usable area, then click again to restore the previous size.
- Keep the Dock and menu bar clear. An optional margin leaves a small gap around zoomed windows and is on by default for new installs.
- Hold a modifier while clicking the green button to use the normal macOS full-screen action.
- Zoom the active window with **Control–Shift–Z**. The menu bar menu also has zoom and restore commands.
- Choose whether Fix Green starts at login or shows its menu bar icon. If the icon is hidden, open Fix Green from Spotlight or press **Control–Shift–,** to return to Settings.
- Check GitHub for updates from the menu bar menu. Fix Green does not check in the background.

## Download

Download the latest **Fix-Green-v*.zip** from [GitHub Releases](https://github.com/nikgraphx/FixGreen/releases/latest). Open the ZIP, then move **Fix Green.app** into **Applications** before launching it.

### Accessibility permission

Fix Green needs Accessibility access to detect the green button and move or resize other apps' windows. On first launch, open the app's Settings, choose **Open Accessibility Settings**, then use the **+** button in **System Settings → Privacy & Security → Accessibility** to add `/Applications/Fix Green.app` and turn it on. macOS does not let an app grant this permission to itself.

If window control stops working after an update, remove Fix Green from the Accessibility list and add the updated copy again. macOS can associate this permission with the exact app build, especially while the app is distributed with an ad-hoc signature.

GitHub builds are ad-hoc signed and are not notarized. macOS may show a first-launch security warning. Move the app to Applications, then Control-click it and choose **Open** if macOS blocks the first launch.

## Privacy

Fix Green runs locally and has no account, analytics, or background update check. Accessibility access allows it to detect the green window button and read or change a target window's position and size. Its optional global shortcuts use macOS event monitors. When you choose **Check for Updates**, the app makes a request to GitHub's public release API; it does not send window titles, window contents, or other app data.

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

Select the `OpenRightZoom` scheme in Xcode. To build a universal Release app from Terminal:

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

Each version has a matching entry in [CHANGELOG.md](CHANGELOG.md). Pushing a version tag such as `v1.0.3` starts the macOS build workflow, which compiles an Apple Silicon and Intel app and attaches a ZIP containing **Fix Green.app** to the GitHub Release. The workflow first uploads the ZIP to a draft release, then publishes it after the asset is ready.

## License and origin

Fix Green is based on [Open Right Zoom](https://github.com/Michele0303/open-right-zoom). The upstream MIT license and its copyright notice are retained in [LICENSE](LICENSE); keep that notice with copies and distributions. The README credits the original project and describes Fix Green's additions.

## Security and support

Please report security issues privately using the instructions in [SECURITY.md](SECURITY.md). For general help, email [nikgraphx@gmail.com](mailto:nikgraphx@gmail.com?subject=Fix%20Green%20support).
