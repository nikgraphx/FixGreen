import AppKit
import SwiftUI
import Combine

class SettingsWindowController: NSWindowController {
    private var onboardingObserver: AnyCancellable?

    init(settings: AppSettings) {
        let view = SettingsView(settings: settings)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Fix Green Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 420, height: settings.hasCompletedOnboarding ? 370 : 560))
        window.center()
        super.init(window: window)

        onboardingObserver = settings.$hasCompletedOnboarding.dropFirst().sink { [weak self] completed in
            DispatchQueue.main.async {
                self?.window?.setContentSize(NSSize(width: 420, height: completed ? 370 : 560))
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }
}
