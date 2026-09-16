import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(PreferenceKeys.adaptiveRingPriority) private var adaptiveRingPriorityRaw = PerformancePreference.automatic.rawValue
    @AppStorage(PreferenceKeys.adaptiveRingColorCoding) private var adaptiveRingColorCoding = false
    @StateObject private var launchAtLogin = LaunchAtLoginService()
    @ObservedObject private var adaptiveRingMonitor = AdaptiveRingMonitor.shared
    private let deviceContextService = DeviceContextService()
    #if DEBUG
    @AppStorage(PreferenceKeys.simulateDesktopMac) private var simulateDesktopMac = false
    #endif

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

            if showsAdaptiveRingSettings {
                Section("Adaptive Ring") {
                    Picker("Adaptive Ring Priority", selection: adaptiveRingPriority) {
                        ForEach(PerformancePreference.allCases, id: \.self) { preference in
                            Text(preference.rawValue).tag(preference)
                        }
                    }
                    Text("Used only when multiple system conditions need attention. Critical conditions can still take priority.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Adaptive Ring Color Coding", isOn: $adaptiveRingColorCoding)
                }
            }

            #if DEBUG
            if !MarketingCaptureMode.isEnabled {
                DebugPerformanceDiagnosticsView()
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
            if showsAdaptiveRingSettings {
                adaptiveRingMonitor.setPreference(adaptiveRingPriority.wrappedValue)
            }
        }
        .onChange(of: adaptiveRingPriorityRaw) { _ in
            if showsAdaptiveRingSettings {
                adaptiveRingMonitor.setPreference(adaptiveRingPriority.wrappedValue)
            }
        }
    }

    private var settingsHeight: CGFloat {
        #if DEBUG
        MarketingCaptureMode.isEnabled ? 300 : 780
        #else
        300
        #endif
    }

    private var adaptiveRingPriority: Binding<PerformancePreference> {
        Binding(
            get: { PerformancePreference(rawValue: adaptiveRingPriorityRaw) ?? .automatic },
            set: { adaptiveRingPriorityRaw = $0.rawValue }
        )
    }

    private var showsAdaptiveRingSettings: Bool {
        #if DEBUG
        AdaptiveRingSettingsEligibility.isEligible(
            for: deviceContextService.current(),
            simulateDesktop: simulateDesktopMac
        )
        #else
        AdaptiveRingSettingsEligibility.isEligible(for: deviceContextService.current())
        #endif
    }
}
