import SwiftUI
import ApplicationServices

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
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            }
            .padding(.horizontal, 14)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                Image(systemName: hasAccessibility ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(hasAccessibility ? Color.green : Color.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasAccessibility ? "Accessibility access granted" : "Accessibility access required")
                        .font(.callout.weight(.medium))
                    if !hasAccessibility { Text("Required to control other apps' windows").font(.caption).foregroundStyle(.secondary) }
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
        .frame(width: 420, height: settings.hasCompletedOnboarding ? 330 : 560)
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

    private var onboardingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.blue)
                Text("Welcome to Fix Green")
                    .font(.headline)
            }
            Text("To resize other apps' windows, macOS needs to grant Fix Green Accessibility access. Open Privacy & Security → Accessibility, enable Fix Green, then return here. We’ll notice when access is ready. If it isn't listed, add the app with the + button.")
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
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        hasAccessibility = AXIsProcessTrustedWithOptions(options)
    }

    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
