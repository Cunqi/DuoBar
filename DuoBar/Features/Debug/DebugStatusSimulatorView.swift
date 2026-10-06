import DuoBarCore
import SwiftUI

#if DEBUG
private struct DebugStatusSimulatorView: View {
    let statusStore: SystemStatusStore
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    @ObservedObject private var adaptiveRingMonitor = AdaptiveRingMonitor.shared

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Label("Debug Simulator", systemImage: "hammer")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu("Simulate") {
                    Menu("Battery Level") {
                        ForEach(DebugBatteryLevel.allCases) { level in
                            Button(level.title) { statusStore.applyDebugBatteryLevel(level) }
                        }
                    }
                    Menu("Battery Power") {
                        ForEach(DebugPowerState.allCases) { powerState in
                            Button(powerState.rawValue) { statusStore.applyDebugPowerState(powerState) }
                        }
                    }
                    Menu("Low Power Mode") {
                        ForEach(DebugLowPowerMode.allCases) { lowPowerMode in
                            Button(lowPowerMode.rawValue) { statusStore.applyDebugLowPowerMode(lowPowerMode) }
                        }
                    }
                    Menu("Battery Color Coding") {
                        Button("Off") { batteryColorCoding = false }
                        Button("On") { batteryColorCoding = true }
                    }
                    Menu("Network") {
                        ForEach(DebugNetworkState.allCases) { networkState in
                            Button(networkState.rawValue) { statusStore.applyDebugNetworkState(networkState) }
                        }
                    }
                    Menu("Volume") {
                        ForEach(DebugVolumeState.allCases) { volumeState in
                            Button(volumeState.rawValue) { statusStore.applyDebugVolumeState(volumeState) }
                        }
                    }
                    Menu("Audio Connection") {
                        ForEach(DebugAudioDeviceState.allCases) { deviceState in
                            Button(deviceState.rawValue) { statusStore.applyDebugAudioDeviceState(deviceState) }
                        }
                    }
                    Divider()
                    Button("Restore Live Data") { statusStore.restoreLiveStatus() }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Divider()

            LabeledContent("Laptop Ring Mode", value: laptopRingModeLabel)
            LabeledContent("Charging session", value: chargingSessionLabel)
            LabeledContent("Adaptive telemetry lease", value: adaptiveRingMonitor.monitoringOwnerCount > 0 ? "Active" : "Inactive")
            LabeledContent("Adaptive monitor", value: adaptiveRingMonitor.isMonitoring ? "Running" : "Stopped")
            LabeledContent("Adaptive source", value: adaptiveRingMonitor.debugTestSource.rawValue)
            LabeledContent("Brightness", value: brightnessLabel)
            LabeledContent("Adaptive metric", value: adaptiveRingMonitor.state.diagnosticLabel)
            LabeledContent("Adaptive progress", value: adaptiveProgressLabel)
            LabeledContent("Final ring override", value: finalRingOverrideLabel)

        }
        .padding(.horizontal, 6)
        .frame(minHeight: 26)
    }

    private var laptopRingModeLabel: String {
        switch statusStore.laptopRingModeState.mode {
        case .battery: "Battery"
        case .adaptive: "Adaptive"
        }
    }

    private var chargingSessionLabel: String {
        guard let start = statusStore.laptopRingModeState.sessionStartPercentage,
              let target = statusStore.laptopRingModeState.targetPercentage
        else { return "None" }
        let waiting = statusStore.laptopRingModeState.isWaitingForFullChargeDelay ? " · waiting for full delay" : ""
        return "\(start)% → \(target)%\(waiting)"
    }

    private var brightnessLabel: String {
        guard let availability = adaptiveRingMonitor.brightnessSnapshot?.availability else { return "Sampling…" }
        switch availability {
        case .available(let value): return String(format: "%.0f%%", value * 100)
        case .unavailable: return "Unavailable"
        }
    }

    private var adaptiveProgressLabel: String {
        let target = AdaptiveRingVisualTarget(state: adaptiveRingMonitor.state).progress
        return String(format: "%.1f%%", target * 100)
    }

    private var finalRingOverrideLabel: String {
        guard statusStore.usesAdaptiveRing else { return "Battery Ring" }
        let target = AdaptiveRingVisualTarget(state: adaptiveRingMonitor.state).progress
        return String(format: "%.1f%%", target * 100)
    }
}
#endif
