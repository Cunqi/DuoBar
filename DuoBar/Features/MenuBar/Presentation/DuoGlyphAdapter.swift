import DuoBarCore
import DuoBarKit
import SwiftUI

enum DuoGlyphAdapter {
    static func renderState(
        status: SystemStatus,
        presentation: StatusPresentation,
        ringPresentation: DuoPersistentRingPresentation?,
        centerStateOverride: DuoCenterState?,
        batteryColorCodingEnabled: Bool
    ) -> GlyphRenderState {
        let state = DuoGlyphState(
            status: status,
            presentation: presentation,
            ringPresentation: ringPresentation,
            centerStateOverride: centerStateOverride,
            batteryColorCodingEnabled: batteryColorCodingEnabled
        )
        return GlyphRenderState(
            ringPresentation: GlyphRingPresentation(
                mode: state.ringPresentation.mode == .battery ? .battery : .adaptive,
                progress: state.ringPresentation.progress,
                opacity: state.ringPresentation.opacity,
                batteryPresentation: GlyphBatteryPresentation(
                    boltPlacement: state.batteryPresentation.boltPlacement == .none ? .none : .topGap,
                    colorRole: batteryColorRole(state.batteryPresentation.colorRole)
                )
            ),
            centerState: centerState(state.centerState),
            volumeActiveDotCount: state.volumeActiveDotCount,
            feedback: feedback(state.feedback),
            audioEventID: state.audioEventID,
            nonChargingBatteryColorRole: nonChargingBatteryColorRole(
                battery: status.battery,
                colorCodingEnabled: batteryColorCodingEnabled
            )
        )
    }

    static func centerState(_ state: DuoCenterState) -> GlyphCenterState {
        switch state {
        case let .wifi(level): .wifi(wifiSignalLevel(level))
        case .ethernet: .ethernet
        case .offline: .offline
        case .other: .other
        case .unavailable: .unavailable
        case .airPodsPro: .airPodsPro
        case .airPodsMax: .airPodsMax
        case .airPods: .airPods
        case .headphones: .headphones
        case .audioDevice: .audioDevice
        case .performanceCPU: .performanceCPU
        case .performanceMemory: .performanceMemory
        case .performanceThermal: .performanceThermal
        }
    }

    private static func wifiSignalLevel(_ level: WiFiSignalLevel) -> GlyphWiFiSignalLevel {
        switch level {
        case .strong: .strong
        case .medium: .medium
        case .weak: .weak
        case .disconnected: .disconnected
        case .disabled: .disabled
        case .unavailable: .unavailable
        }
    }

    private static func batteryColorRole(_ role: BatteryRingColorRole) -> GlyphBatteryColorRole {
        switch role {
        case .monochrome: .monochrome
        case .charging: .charging
        case .lowPowerMode: .lowPowerMode
        case .lowBattery: .lowBattery
        }
    }

    private static func feedback(_ feedback: DuoSemanticFeedback) -> GlyphSemanticFeedback {
        switch feedback {
        case .none: .none
        case .charging: .charging
        case .lowBattery: .lowBattery
        case .audioConnected: .audioConnected
        }
    }

    private static func nonChargingBatteryColorRole(battery: BatteryStatus, colorCodingEnabled: Bool) -> GlyphBatteryColorRole {
        guard colorCodingEnabled, !battery.isPluggedIn else { return .monochrome }
        if battery.isLowPowerModeEnabled { return .lowPowerMode }
        if let percentage = battery.percentage, percentage < 20 { return .lowBattery }
        return .monochrome
    }
}

extension DuoGlyphView {
    init(
        status: SystemStatus,
        presentation: StatusPresentation = .normal,
        metrics: DuoGlyphMetrics = .standard,
        animationsEnabled: Bool = true,
        ringPresentation: DuoPersistentRingPresentation? = nil,
        centerStateOverride: DuoCenterState? = nil,
        ringTransitionAnimation: Animation? = nil,
        usesCustomRingTransition: Bool = false,
        ringColorOverride: Color? = nil,
        batteryColorCodingEnabled: Bool = false,
        chargingBoltProgressOverride: CGFloat? = nil,
        chargingTrackProgressOverride: CGFloat? = nil,
        chargingColorMixOverride: CGFloat? = nil
    ) {
        self.init(
            state: DuoGlyphAdapter.renderState(
                status: status,
                presentation: presentation,
                ringPresentation: ringPresentation,
                centerStateOverride: centerStateOverride,
                batteryColorCodingEnabled: batteryColorCodingEnabled
            ),
            metrics: metrics,
            animationsEnabled: animationsEnabled,
            ringTransitionAnimation: ringTransitionAnimation,
            usesCustomRingTransition: usesCustomRingTransition,
            ringColorOverride: ringColorOverride,
            chargingBoltProgressOverride: chargingBoltProgressOverride,
            chargingTrackProgressOverride: chargingTrackProgressOverride,
            chargingColorMixOverride: chargingColorMixOverride
        )
    }
}
