import ServiceManagement
import SwiftUI

enum SettingsPane: String, Hashable, Identifiable {
    case general
    case menuBar
    #if DEBUG
    case debugDiagnostics
    case debugGlyphTuning
    #endif

    var id: Self { self }

    var title: String {
        switch self {
        case .general: localized("General")
        case .menuBar: localized("Menu Bar Icon")
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
            adaptiveRingMonitor.setPreference(adaptiveRingPriority)
        }
        .onChange(of: adaptiveRingPriorityRaw) { _ in
            adaptiveRingMonitor.setPreference(adaptiveRingPriority)
        }
    }

    @ViewBuilder
    private func detail(for pane: SettingsPane) -> some View {
        switch pane {
        case .general: GeneralSettingsPane()
        case .menuBar: MenuBarSettingsPane(hasBattery: hasBattery)
        #if DEBUG
        case .debugDiagnostics: SettingsPaneForm { DebugPerformanceDiagnosticsView() }
        case .debugGlyphTuning: SettingsPaneForm { DebugDuoGlyphTuningView() }
        #endif
        }
    }

    private var visiblePanes: [SettingsPane] {
        var panes: [SettingsPane] = [.general, .menuBar]
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

    private var hasBattery: Bool {
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
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
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

            Section {
                Toggle(localized("Show battery percentage in popover"), isOn: $showBatteryPercentage)
            }
        }
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}

private struct MenuBarSettingsPane: View {
    let hasBattery: Bool

    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(PreferenceKeys.menuBarIconScale) private var menuBarIconScale = MenuBarIconSize.defaultScale
    @AppStorage(PreferenceKeys.ringContent) private var ringContentRaw = RingContent.defaultValue.rawValue
    @AppStorage(PreferenceKeys.ringPressureOverride) private var ringPressureOverride = true
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    @AppStorage(PreferenceKeys.adaptiveRingPriority) private var adaptiveRingPriorityRaw = PerformancePreference.automatic.rawValue
    @AppStorage(PreferenceKeys.adaptiveRingColorCoding) private var adaptiveRingColorCoding = false

    var body: some View {
        SettingsPaneForm {
            Section {
                Toggle(localized("Enable animations"), isOn: $animationsEnabled)

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

            Section(localized("Outer Ring")) {
                Picker(localized("Ring shows"), selection: ringContent) {
                    ForEach(RingContent.options(hasBattery: hasBattery)) { content in
                        Text(content.localizedDisplayName).tag(content)
                    }
                }

                if resolvedRingContent.isFixedMetric {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(localized("Show high load alerts"), isOn: $ringPressureOverride)
                        Text(localized("Sustained CPU, memory, or thermal pressure temporarily takes over the ring."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if showsBatteryOptions {
                    Toggle(localized("Battery Color Coding"), isOn: $batteryColorCoding)
                }

                if showsPressureOptions {
                    Picker(localized("Adaptive Ring Priority"), selection: adaptiveRingPriority) {
                        ForEach(PerformancePreference.allCases, id: \.self) { preference in
                            Text(preference.localizedDisplayName).tag(preference)
                        }
                    }
                    Text(localized("Used only when multiple system conditions need attention. Critical conditions can still take priority."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(localized("Adaptive Ring Color Coding"), isOn: $adaptiveRingColorCoding)
                }
            }
        }
    }

    private var resolvedRingContent: RingContent {
        let content = RingContent(rawValue: ringContentRaw) ?? .defaultValue
        return RingContent.options(hasBattery: hasBattery).contains(content) ? content : .defaultValue
    }

    private var showsBatteryOptions: Bool {
        hasBattery && !resolvedRingContent.isFixedMetric
    }

    private var showsPressureOptions: Bool {
        resolvedRingContent.isFixedMetric ? ringPressureOverride : !hasBattery
    }

    private var ringContent: Binding<RingContent> {
        Binding(
            get: { resolvedRingContent },
            set: { ringContentRaw = $0.rawValue }
        )
    }

    private var resolvedMenuBarIconScale: Binding<Double> {
        Binding(
            get: { MenuBarIconSize.resolve(menuBarIconScale) },
            set: { menuBarIconScale = MenuBarIconSize.resolve($0) }
        )
    }

    private var adaptiveRingPriority: Binding<PerformancePreference> {
        Binding(
            get: { PerformancePreference(rawValue: adaptiveRingPriorityRaw) ?? .automatic },
            set: { adaptiveRingPriorityRaw = $0.rawValue }
        )
    }
}
