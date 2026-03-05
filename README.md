# Open Right Zoom

A free, open-source clone of "Right Zoom for Mac". Click the green zoom button to maximize windows without entering fullscreen — Dock and menu bar stay visible.

## Features

- Intercepts clicks on the green zoom/fullscreen button
- Maximizes the window to the visible screen area (excluding Dock and menu bar)
- Click again to restore the previous window size (toggle behavior)
- Hold Shift, Ctrl, Cmd, or Option while clicking → standard macOS behavior (fullscreen)
- Enable/disable from the menu bar
- Launch at Login support (macOS 13+)

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (to build from source)

## Installation

1. Download `OpenRightZoom-vX.X.X.zip` from [Releases](../../releases)
2. Unzip and move `OpenRightZoom.app` to `/Applications`
3. First launch — macOS will block the app since it's not from the App Store. Run this once in Terminal:
   ```bash
   xattr -cr /Applications/OpenRightZoom.app
   ```
4. Open the app and grant Accessibility permission when prompted (Settings → Privacy & Security → Accessibility)

## Build from source

1. Open `OpenRightZoom.xcodeproj` in Xcode
2. Press `Cmd+R` to build and run
3. Grant Accessibility permission when prompted (Settings → Privacy & Security → Accessibility)

## Usage

After launching, the app lives in the menu bar. Click the arrow icon to:
- Toggle enable/disable
- Open Settings
- Quit

## How It Works

The app uses a `CGEventTap` to intercept mouse clicks and the Accessibility API (`AXUIElement`) to:
1. Detect clicks on the zoom button (`AXZoomButton`)
2. Get the window's current frame
3. Set the window size to `NSScreen.visibleFrame` (which excludes Dock and menu bar)
4. Save/restore the previous frame for toggle behavior

## Permissions

Requires Accessibility access. The app is **not sandboxed** and distributed outside the App Store.

## License

MIT — see [LICENSE](LICENSE)
