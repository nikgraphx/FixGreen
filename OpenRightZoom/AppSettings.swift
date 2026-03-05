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

    weak var windowMaximizer: WindowMaximizer?

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "isEnabled") == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = defaults.bool(forKey: "isEnabled")
        }
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }
}
