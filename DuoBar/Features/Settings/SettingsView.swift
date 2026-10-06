import DuoBarCore
import SwiftUI

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
        case .popover: PopoverSettingsPane(hasBattery: hasBattery)
        #if DEBUG
        case .debugDiagnostics: SettingsPaneForm { DebugPerformanceDiagnosticsView() }
        case .debugGlyphTuning: SettingsPaneForm { DebugDuoGlyphTuningView() }
        #endif
        }
    }

    private var visiblePanes: [SettingsPane] {
        var panes: [SettingsPane] = [.general, .menuBar, .popover]
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
