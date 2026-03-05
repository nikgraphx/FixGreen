import SwiftUI
import ApplicationServices

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var hasAccessibility: Bool = false
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Right Zoom")
                        .font(.title2.bold())
                    Text("Maximize windows without fullscreen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Settings toggles
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Activate Open Right Zoom", isOn: $settings.isEnabled)
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }

            Divider()

            // Accessibility status
            HStack(spacing: 8) {
                Circle()
                    .fill(hasAccessibility ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(hasAccessibility ? "Accessibility access granted" : "Accessibility access required")
                    .font(.callout)
                    .foregroundColor(hasAccessibility ? .primary : .secondary)
                Spacer()
                if !hasAccessibility {
                    Button("Grant Access") {
                        openAccessibilityPreferences()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 380, height: 260)
        .onAppear {
            checkAccessibility()
            timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                checkAccessibility()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func checkAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options)
        if trusted != hasAccessibility {
            hasAccessibility = trusted
            // Restart maximizer if we just got access and are enabled
            if trusted && settings.isEnabled {
                // windowMaximizer reference is via settings
            }
        }
    }

    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
