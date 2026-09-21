import ServiceManagement
import SwiftUI

enum SettingsPane: String, Hashable, Identifiable {
    case general
    case menuBar
    case batteryRing
    case adaptiveRing
    #if DEBUG
    case debugDiagnostics
    case debugGlyphTuning
    #endif

    var id: Self { self }

    var title: String {
        switch self {
        case .general: localized("General")
        case .menuBar: localized("Menu Bar")
        case .batteryRing: localized("Battery Ring")
        case .adaptiveRing: localized("Adaptive Ring")
        #if DEBUG
        case .debugDiagnostics: "Diagnostics"
        case .debugGlyphTuning: "Glyph Tuning"
        #endif
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .menuBar: "menubar.rectangle"
        case .batteryRing: "battery.100percent"
        case .adaptiveRing: "gauge.medium"
        #if DEBUG
        case .debugDiagnostics: "stethoscope"
        case .debugGlyphTuning: "slider.horizontal.3"
        #endif
        }
    }
}

struct SettingsView: View {
    @AppStorage(PreferenceKeys.adaptiveRingPriority) private var adaptiveRingPriorityRaw = PerformancePreference.automatic.rawValue
    @ObservedObject private var adaptiveRingMonitor = AdaptiveRingMonitor.shared
    @State private var selection: SettingsPane = .general
    private let deviceContextService = DeviceContextService()
    #if DEBUG
    @AppStorage(PreferenceKeys.simulateDesktopMac) private var simulateDesktopMac = false
    #endif

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(panes: visiblePanes, selection: resolvedSelection) { selection = $0 }
            Divider()
            detail(for: resolvedSelection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(resolvedSelection.title)
        .frame(width: 640, height: settingsHeight)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            if showsAdaptiveRingSettings {
                adaptiveRingMonitor.setPreference(adaptiveRingPriority)
            }
        }
        .onChange(of: adaptiveRingPriorityRaw) { _ in
            if showsAdaptiveRingSettings {
                adaptiveRingMonitor.setPreference(adaptiveRingPriority)
            }
        }
    }

    @ViewBuilder
    private func detail(for pane: SettingsPane) -> some View {
        switch pane {
        case .general: GeneralSettingsPane()
        case .menuBar: MenuBarSettingsPane()
        case .batteryRing: BatteryRingSettingsPane()
        case .adaptiveRing: AdaptiveRingSettingsPane()
        #if DEBUG
        case .debugDiagnostics: SettingsPaneForm { DebugPerformanceDiagnosticsView() }
        case .debugGlyphTuning: SettingsPaneForm { DebugDuoGlyphTuningView() }
        #endif
        }
    }

    private var visiblePanes: [SettingsPane] {
        var panes: [SettingsPane] = [.general, .menuBar]
        if showsBatteryRingSettings {
            panes.append(.batteryRing)
        }
        if showsAdaptiveRingSettings {
            panes.append(.adaptiveRing)
        }
        #if DEBUG
        if !MarketingCaptureMode.isEnabled {
            panes.append(contentsOf: [.debugDiagnostics, .debugGlyphTuning])
        }
        #endif
        return panes
    }

    private var resolvedSelection: SettingsPane {
        guard visiblePanes.contains(selection) else { return .general }
        return selection
    }

    private var settingsHeight: CGFloat {
        #if DEBUG
        MarketingCaptureMode.isEnabled ? 360 : 560
        #else
        360
        #endif
    }

    private var adaptiveRingPriority: PerformancePreference {
        PerformancePreference(rawValue: adaptiveRingPriorityRaw) ?? .automatic
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

    private var showsBatteryRingSettings: Bool {
        #if DEBUG
        deviceContextService.current(simulateDesktop: simulateDesktopMac).ringBehavior == .batteryRing
        #else
        deviceContextService.current().ringBehavior == .batteryRing
        #endif
    }
}

private struct SettingsSidebar: View {
    let panes: [SettingsPane]
    let selection: SettingsPane
    let select: (SettingsPane) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(panes) { pane in
                SettingsSidebarRow(pane: pane, isSelected: pane == selection) {
                    select(pane)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct SettingsSidebarRow: View {
    let pane: SettingsPane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(pane.title)
                    .lineLimit(1)
            } icon: {
                Image(systemName: pane.symbol)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 18)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SettingsPaneForm<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
    }
}

private struct GeneralSettingsPane: View {
    @AppStorage(PreferenceKeys.openOnHover) private var openOnHover = false
    @StateObject private var launchAtLogin = LaunchAtLoginService()

    var body: some View {
        SettingsPaneForm {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(localized("Open on Hover"), isOn: $openOnHover)
                        .toggleStyle(.switch)
                    Text(localized("Open DuoBar when the pointer moves over the menu bar icon."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(
                    localized("Launch DuoBar at login"),
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: launchAtLogin.setEnabled
                    )
                )

                if launchAtLogin.requiresApproval {
                    Text(localized("Approval is required in System Settings → General → Login Items."))
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
        }
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}

private struct MenuBarSettingsPane: View {
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(PreferenceKeys.menuBarIconScale) private var menuBarIconScale = MenuBarIconSize.defaultScale

    var body: some View {
        SettingsPaneForm {
            Section {
                Toggle(localized("Show battery percentage in popover"), isOn: $showBatteryPercentage)
                Toggle(localized("Enable animations"), isOn: $animationsEnabled)
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("Icon Size"))
                    HStack(spacing: 10) {
                        Text(localized("Small"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(
                            value: resolvedMenuBarIconScale,
                            in: MenuBarIconSize.minimumScale...MenuBarIconSize.maximumScale,
                            step: MenuBarIconSize.step
                        )
                        .accessibilityLabel(localized("Menu bar icon size"))
                        .accessibilityValue(localized("%d%%", Int((MenuBarIconSize.resolve(menuBarIconScale) * 100).rounded())))
                        Text(localized("Large"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(localized("Adjust DuoBar to better match your menu bar."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var resolvedMenuBarIconScale: Binding<Double> {
        Binding(
            get: { MenuBarIconSize.resolve(menuBarIconScale) },
            set: { menuBarIconScale = MenuBarIconSize.resolve($0) }
        )
    }
}

private struct BatteryRingSettingsPane: View {
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false

    var body: some View {
        SettingsPaneForm {
            Section {
                Toggle(localized("Battery Color Coding"), isOn: $batteryColorCoding)
            }
        }
    }
}

private struct AdaptiveRingSettingsPane: View {
    @AppStorage(PreferenceKeys.adaptiveRingPriority) private var adaptiveRingPriorityRaw = PerformancePreference.automatic.rawValue
    @AppStorage(PreferenceKeys.adaptiveRingColorCoding) private var adaptiveRingColorCoding = false

    var body: some View {
        SettingsPaneForm {
            Section {
                Picker(localized("Adaptive Ring Priority"), selection: adaptiveRingPriority) {
                    ForEach(PerformancePreference.allCases, id: \.self) { preference in
                        Text(preference.localizedDisplayName).tag(preference)
                    }
                }
                Text(localized("Used only when multiple system conditions need attention. Critical conditions can still take priority."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(localized("Adaptive Ring Color Coding"), isOn: $adaptiveRingColorCoding)
            }
        }
    }

    private var adaptiveRingPriority: Binding<PerformancePreference> {
        Binding(
            get: { PerformancePreference(rawValue: adaptiveRingPriorityRaw) ?? .automatic },
            set: { adaptiveRingPriorityRaw = $0.rawValue }
        )
    }
}
