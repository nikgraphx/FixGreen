import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var settingsWindowController: SettingsWindowController?
    let settings = AppSettings()
    let windowMaximizer = WindowMaximizer()
    private var accessibilityTimer: Timer?
    private var settingsHotKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        settings.windowMaximizer = windowMaximizer
        windowMaximizer.settings = settings

        statusBarController = StatusBarController(settings: settings, windowMaximizer: windowMaximizer) { [weak self] in
            self?.openSettings()
        }
        registerSettingsHotKey()

        let accessibilityGranted = isAccessibilityGranted()
        if !settings.hasCompletedOnboarding || !accessibilityGranted {
            openSettings()
        }

        if accessibilityGranted {
            if settings.isEnabled { windowMaximizer.start() }
        } else {
            // Keep checking after showing first-run guidance and the permission state.
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    private func registerSettingsHotKey() {
        settingsHotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection([.control, .shift, .command, .option])
            guard event.keyCode == 43, modifiers == [.control, .shift] else { return }
            DispatchQueue.main.async { self?.openSettings() }
        }
    }
}
