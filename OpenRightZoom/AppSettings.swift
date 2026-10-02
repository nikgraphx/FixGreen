import Foundation
import ServiceManagement

class AppSettings: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
            if isEnabled {
                windowMaximizer?.start()
            } else {
                windowMaximizer?.stop()
            }
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    @Published var showMenuBarIcon: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarIcon, forKey: "showMenuBarIcon")
        }
    }

    @Published var useWindowMargins: Bool {
        didSet {
            UserDefaults.standard.set(useWindowMargins, forKey: "useWindowMargins")
        }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    weak var windowMaximizer: WindowMaximizer?

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "isEnabled") == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = defaults.bool(forKey: "isEnabled")
        }
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.showMenuBarIcon = defaults.object(forKey: "showMenuBarIcon") == nil
            ? true
            : defaults.bool(forKey: "showMenuBarIcon")
        // Match macOS Sequoia's default tiled-window spacing for new installs.
        self.useWindowMargins = defaults.object(forKey: "useWindowMargins") == nil
            ? true
            : defaults.bool(forKey: "useWindowMargins")
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
    }
}
