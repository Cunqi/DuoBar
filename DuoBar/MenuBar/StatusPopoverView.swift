import AppKit
import SwiftUI

struct StatusPopoverView: View {
    @ObservedObject private var statusStore: SystemStatusStore
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    private let onClose: () -> Void

    init(statusStore: SystemStatusStore, onClose: @escaping () -> Void) {
        self.statusStore = statusStore
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("DuoBar")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                DuoGlyphView(
                    status: statusStore.status,
                    metrics: DuoGlyphMetrics.standard.sized(20),
                    animationsEnabled: false
                )
            }
            .padding(.horizontal, 2)

            StatusRow(
                symbol: networkSymbol,
                title: "Network",
                detail: networkDetail,
                stateText: networkState,
                tint: .primary
            )

            VolumeStatusRow(
                volume: statusStore.status.audio.volume,
                hasOutputDevice: statusStore.status.audio.defaultOutput != nil,
                playbackDeviceIdentifier: statusStore.status.audio.defaultOutput?.uid,
                onSetVolume: statusStore.setVolume,
                onSetMuted: statusStore.setMuted
            )

            StatusRow(
                symbol: batterySymbol,
                title: "Battery",
                detail: batteryDetail,
                stateText: batteryPercentage,
                tint: .primary
            )

            StatusRow(
                symbol: audioOutputSymbol,
                title: "Audio Output",
                detail: audioOutputDetail,
                stateText: audioOutputState,
                tint: .primary
            )

            #if DEBUG
            if !MarketingCaptureMode.isEnabled {
                DebugStatusSimulatorView(statusStore: statusStore)
            }
            #endif

            Divider()

            HStack(spacing: 6) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    NSApp.activate(ignoringOtherApps: true)
                    onClose()
                })

                Spacer()

                Button("Quit DuoBar") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .font(.system(size: 11.5, weight: .medium))
            .padding(.horizontal, 3)
        }
        .padding(12)
        .frame(width: 304)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            statusStore.requestWiFiSSIDAccess()
        }
    }

    private var networkSymbol: String {
        let network = statusStore.status.network
        guard network.isConnected else { return "network.slash" }
        switch network.transport {
        case .wifi: return "wifi"
        case .ethernet: return "cable.connector.horizontal"
        case .other: return "ellipsis.circle"
        case .none: return "network.slash"
        }
    }

    private var networkDetail: String {
        let network = statusStore.status.network
        guard network.isAvailable else { return "No network interface" }
        guard network.isConnected else {
            return network.isWiFiPoweredOn == false ? "Wi-Fi disabled" : "Not connected"
        }
        switch network.transport {
        case .wifi: return network.ssid ?? "Network name unavailable"
        case .ethernet: return network.interfaceName ?? "Wired connection"
        case .other: return network.interfaceName ?? "Active connection"
        case .none: return "Not connected"
        }
    }

    private var networkState: String {
        let network = statusStore.status.network
        guard network.isAvailable else { return "Unavailable" }
        guard network.isConnected else { return "Offline" }
        switch network.transport {
        case .wifi: return "Wi-Fi"
        case .ethernet: return "Ethernet"
        case .other: return "Connected"
        case .none: return "Offline"
        }
    }

    private var batterySymbol: String {
        let battery = statusStore.status.battery
        if battery.isCharging { return "battery.100percent.bolt" }
        if battery.isFullyCharged { return "battery.100percent" }
        switch battery.percentage ?? 0 {
        case 76...100: return "battery.100percent"
        case 51...75: return "battery.75percent"
        case 26...50: return "battery.50percent"
        default: return "battery.25percent"
        }
    }

    private var batteryDetail: String {
        let battery = statusStore.status.battery
        if !battery.isAvailable { return "No internal battery" }
        if battery.isFullyCharged { return "Fully charged" }
        if battery.isCharging { return "Charging" }
        if battery.isPluggedIn { return "Power adapter connected" }
        return "Using battery power"
    }

    private var batteryPercentage: String {
        guard showBatteryPercentage else { return "—" }
        return statusStore.status.battery.percentage.map { "\($0)%" } ?? "—"
    }

    private var audioOutputSymbol: String {
        guard let output = statusStore.status.audio.defaultOutput else { return "speaker.slash" }
        if output.transport.isBluetooth {
            return output.temporaryGlyph == .airPods ? "airpodspro" : "headphones"
        }
        return "speaker.wave.2"
    }

    private var audioOutputDetail: String {
        statusStore.status.audio.defaultOutput?.name ?? "No output device"
    }

    private var audioOutputState: String {
        guard let output = statusStore.status.audio.defaultOutput else { return "Unavailable" }
        if output.transport.isBluetooth {
            return output.temporaryGlyph == .airPods ? "AirPods" : "Bluetooth"
        }
        switch output.transport {
        case .builtIn: return "Built-in"
        case .airPlay: return "AirPlay"
        case .usb: return "USB"
        case .hdmi, .displayPort: return "Display"
        case .virtual: return "Virtual"
        case .bluetooth, .bluetoothLE: return "Bluetooth"
        case .other: return "Connected"
        }
    }
}

#if DEBUG
private struct DebugStatusSimulatorView: View {
    let statusStore: SystemStatusStore

    var body: some View {
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
        .padding(.horizontal, 6)
        .frame(height: 26)
    }
}
#endif
