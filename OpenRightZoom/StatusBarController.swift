import AppKit

class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem
    private var settings: AppSettings
    private var windowMaximizer: WindowMaximizer
    private var openSettings: () -> Void
    private weak var restoreMenuItem: NSMenuItem?

    init(settings: AppSettings, windowMaximizer: WindowMaximizer, openSettings: @escaping () -> Void) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = item
        self.settings = settings
        self.windowMaximizer = windowMaximizer
        self.openSettings = openSettings
        super.init()

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Fix Green")
        }

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: settings.isEnabled ? "Disable Fix Green" : "Enable Fix Green",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let zoomItem = NSMenuItem(title: "Zoom Active Window  (⌃⇧Z)", action: #selector(zoomActiveWindow), keyEquivalent: "")
        zoomItem.target = self
        menu.addItem(zoomItem)

        let restoreItem = NSMenuItem(title: "Restore Previous Size", action: #selector(restorePreviousSize), keyEquivalent: "")
        restoreItem.target = self
        restoreItem.isEnabled = windowMaximizer.canRestorePreviousSize
        restoreMenuItem = restoreItem
        menu.addItem(restoreItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Fix Green", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        restoreMenuItem?.isEnabled = windowMaximizer.canRestorePreviousSize
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        buildMenu()
    }

    @objc private func openSettingsWindow() {
        openSettings()
    }

    @objc private func zoomActiveWindow() {
        windowMaximizer.zoomActiveWindow()
        restoreMenuItem?.isEnabled = windowMaximizer.canRestorePreviousSize
    }

    @objc private func restorePreviousSize() {
        windowMaximizer.restorePreviousSize()
        restoreMenuItem?.isEnabled = windowMaximizer.canRestorePreviousSize
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
