import SwiftUI
import ApplicationServices
import Combine

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var hasAccessibility: Bool = false
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !settings.hasCompletedOnboarding {
                onboardingCard
            }
            HStack(spacing: 12) {
                Image("FixGreenMark")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Fix Green").font(.title3.weight(.semibold))
                    Text("Window behavior, your way")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 0) {
                settingRow("Activate Fix Green", detail: "Use the green button to zoom windows", symbol: "arrow.up.left.and.arrow.down.right") {
                    Toggle("Activate Fix Green", isOn: $settings.isEnabled).labelsHidden().toggleStyle(.switch)
                }
                Divider().padding(.leading, 48)
                settingRow("Use macOS window margins", detail: "Leave a small gutter around zoomed windows", symbol: "rectangle.inset.filled") {
                    Toggle("Use macOS window margins", isOn: $settings.useWindowMargins).labelsHidden().toggleStyle(.switch)
                }
                Divider().padding(.leading, 48)
                settingRow("Launch at Login", detail: "Start automatically when you sign in", symbol: "power.circle") {
                    Toggle("Launch at Login", isOn: $settings.launchAtLogin).labelsHidden().toggleStyle(.switch)
                }
                Divider().padding(.leading, 48)
                settingRow("Show menu bar icon", detail: "Reopen Fix Green from Spotlight or press Control–Shift–, to reopen Settings", symbol: "menubar.rectangle") {
                    Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon).labelsHidden().toggleStyle(.switch)
                }
            }
            .padding(.horizontal, 14)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                Image(systemName: hasAccessibility ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(hasAccessibility ? Color.green : Color.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasAccessibility ? "Accessibility access granted" : "Accessibility access required")
                        .font(.callout.weight(.medium))
                    Text("If window control stops after an update, remove Fix Green from the Accessibility list and add the updated copy again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !hasAccessibility {
                        Text("Add this copy in System Settings → Privacy & Security → Accessibility, then turn it on.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Bundle.main.bundleURL.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
                if !hasAccessibility {
                    Button("Open Settings", action: openAccessibilityPreferences)
                        .buttonStyle(.borderedProminent).controlSize(.small)
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(22)
        .frame(width: 420, height: settings.hasCompletedOnboarding ? 450 : 640)
        .onAppear {
            checkAccessibility()
            let statusTimer = Timer(timeInterval: 1.0, repeats: true) { _ in
                DispatchQueue.main.async { checkAccessibility() }
            }
            RunLoop.main.add(statusTimer, forMode: .common)
            timer = statusTimer
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkAccessibility()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var onboardingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.blue)
                Text("Welcome to Fix Green")
                    .font(.headline)
            }
            Text("To resize other apps' windows, Fix Green needs Accessibility access. Click below, then in System Settings use + to add this app and turn it on. The exact app location is shown in the settings window. Return here after granting access.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open Accessibility Settings") {
                    settings.hasCompletedOnboarding = true
                    openAccessibilityPreferences()
                }
                .buttonStyle(.borderedProminent)
                Button("Later") {
                    settings.hasCompletedOnboarding = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func settingRow<Control: View>(
        _ title: String,
        detail: String,
        symbol: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.vertical, 12)
    }

    private func checkAccessibility() {
        hasAccessibility = AXIsProcessTrusted()
    }

    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NSWorkspace.shared.open(url)
        }
    }
}
