import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var settingsWindowController: SettingsWindowController?
    let settings = AppSettings()
    let windowMaximizer = WindowMaximizer()
    private var accessibilityTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        settings.windowMaximizer = windowMaximizer

        statusBarController = StatusBarController(settings: settings) { [weak self] in
            self?.openSettings()
        }

        if isAccessibilityGranted() {
            if settings.isEnabled { windowMaximizer.start() }
        } else {
            // Open settings and keep checking until permission is granted
            openSettings()
            startAccessibilityMonitor()
        }
    }

    private func isAccessibilityGranted() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    private func startAccessibilityMonitor() {
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.isAccessibilityGranted() {
                NSLog("[ORZ] Accessibility granted – starting tap")
                timer.invalidate()
                self.accessibilityTimer = nil
                if self.settings.isEnabled && !self.windowMaximizer.isRunning {
                    self.windowMaximizer.start()
                }
            }
        }
    }

    func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settings: settings)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
