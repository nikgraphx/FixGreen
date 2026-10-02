import AppKit
import Combine

class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem
    private var settings: AppSettings
    private var windowMaximizer: WindowMaximizer
    private var openSettings: () -> Void
    private weak var restoreMenuItem: NSMenuItem?
    private var iconVisibilityObserver: AnyCancellable?

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
        item.isVisible = settings.showMenuBarIcon
        iconVisibilityObserver = settings.$showMenuBarIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak item] isVisible in item?.isVisible = isVisible }

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

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

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

    @objc private func checkForUpdates() {
        guard let url = URL(string: "https://api.github.com/repos/nikgraphx/FixGreen/releases/latest") else { return }
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Fix Green macOS app", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            guard error == nil,
                  let response = response as? HTTPURLResponse,
                  response.statusCode == 200,
                  let data,
                  let release = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = release["tag_name"] as? String,
                  let latestVersion = Self.numericVersion(tag) else {
                DispatchQueue.main.async { self?.showUpdateCheckFailure() }
                return
            }

            let current = Self.numericVersion(currentVersion) ?? []
            let hasUpdate = Self.isVersion(latestVersion, newerThan: current)
            DispatchQueue.main.async {
                self?.showUpdateResult(version: latestVersion.map(String.init).joined(separator: "."), available: hasUpdate)
            }
        }.resume()
    }

    private static func numericVersion(_ value: String) -> [Int]? {
        let version = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let parts = version.split(separator: ".")
        guard !parts.isEmpty, parts.allSatisfy({ Int($0) != nil }) else { return nil }
        return parts.compactMap { Int($0) }
    }

    private static func isVersion(_ candidate: [Int], newerThan installed: [Int]) -> Bool {
        for index in 0..<max(candidate.count, installed.count) {
            let remotePart = index < candidate.count ? candidate[index] : 0
            let localPart = index < installed.count ? installed[index] : 0
            if remotePart != localPart { return remotePart > localPart }
        }
        return false
    }

    private func showUpdateResult(version: String, available: Bool) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        if available {
            alert.messageText = "Fix Green \(version) is available"
            alert.informativeText = "Download the update from GitHub Releases. If the app stops resizing windows afterward, remove Fix Green from System Settings → Privacy & Security → Accessibility, then add the updated copy again."
            alert.addButton(withTitle: "View Release")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn,
               let releaseURL = URL(string: "https://github.com/nikgraphx/FixGreen/releases/latest") {
                NSWorkspace.shared.open(releaseURL)
            }
        } else {
            alert.messageText = "Fix Green is up to date"
            alert.informativeText = "You’re running version \(version)."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func showUpdateCheckFailure() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t check for updates"
        alert.informativeText = "Check your internet connection or visit the Fix Green releases page on GitHub."
        alert.addButton(withTitle: "Open Releases")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let releaseURL = URL(string: "https://github.com/nikgraphx/FixGreen/releases/latest") {
            NSWorkspace.shared.open(releaseURL)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
