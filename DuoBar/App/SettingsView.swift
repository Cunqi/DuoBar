import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @StateObject private var launchAtLogin = LaunchAtLoginService()

    var body: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show battery percentage in popover", isOn: $showBatteryPercentage)
                Toggle("Enable animations", isOn: $animationsEnabled)
            }

            Section("General") {
                Toggle(
                    "Launch DuoBar at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: launchAtLogin.setEnabled
                    )
                )

                if launchAtLogin.requiresApproval {
                    Text("Approval is required in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = launchAtLogin.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            #if DEBUG
            if !MarketingCaptureMode.isEnabled {
                DebugDuoGlyphTuningView()
            }
            #endif
        }
        .formStyle(.grouped)
        .scenePadding()
        .frame(width: 420, height: settingsHeight)
        .navigationTitle("DuoBar Settings")
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            launchAtLogin.refresh()
        }
    }

    private var settingsHeight: CGFloat {
        #if DEBUG
        MarketingCaptureMode.isEnabled ? 300 : 540
        #else
        300
        #endif
    }
}
