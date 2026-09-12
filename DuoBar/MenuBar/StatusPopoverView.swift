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
                    metrics: DuoGlyphMetrics.standard.sized(19),
                    animationsEnabled: false
                )
            }
            .padding(.horizontal, 2)

            StatusRow(
                symbol: wifiSymbol,
                title: "Wi-Fi",
                detail: wifiDetail,
                stateText: wifiState,
                tint: statusStore.status.wifi.isConnected ? .blue : .orange
            )

            StatusRow(
                symbol: "antenna.radiowaves.left.and.right",
                title: "Bluetooth",
                detail: bluetoothDetail,
                stateText: bluetoothState,
                tint: statusStore.status.bluetooth.isPoweredOn ? .blue : .orange
            )

            StatusRow(
                symbol: batterySymbol,
                title: "Battery",
                detail: batteryDetail,
                stateText: batteryPercentage,
                tint: batteryTint
            )

            #if DEBUG
            DebugStatusSimulatorView(statusStore: statusStore)
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
        .frame(width: 296)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            statusStore.requestWiFiSSIDAccess()
        }
    }

    private var wifiSymbol: String {
        guard statusStore.status.wifi.isPoweredOn else { return "wifi.slash" }
        return statusStore.status.wifi.isConnected ? "wifi" : "wifi.exclamationmark"
    }

    private var wifiDetail: String {
        let wifi = statusStore.status.wifi
        if !wifi.isAvailable { return "No Wi-Fi interface" }
        if !wifi.isPoweredOn { return "Radio disabled" }
        if !wifi.isConnected { return "Not connected" }
        return wifi.ssid ?? "Network name unavailable"
    }

    private var wifiState: String {
        let wifi = statusStore.status.wifi
        if !wifi.isAvailable { return "Unavailable" }
        if !wifi.isPoweredOn { return "Off" }
        return wifi.isConnected ? "Connected" : "Offline"
    }

    private var bluetoothDetail: String {
        if !statusStore.status.bluetooth.isAvailable { return "No controller detected" }
        return statusStore.status.bluetooth.isPoweredOn ? "Controller available" : "Radio disabled"
    }

    private var bluetoothState: String {
        guard statusStore.status.bluetooth.isAvailable else { return "Unavailable" }
        return statusStore.status.bluetooth.isPoweredOn ? "On" : "Off"
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

    private var batteryTint: Color {
        let battery = statusStore.status.battery
        if battery.isCharging || battery.isFullyCharged { return .green }
        if (battery.percentage ?? 100) <= 10 { return .red }
        if (battery.percentage ?? 100) <= 20 { return .orange }
        return .primary
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
                        Button(level.title) {
                            statusStore.applyDebugBatteryLevel(level)
                        }
                    }
                }
                Menu("Battery Power") {
                    ForEach(DebugPowerState.allCases) { powerState in
                        Button(powerState.rawValue) {
                            statusStore.applyDebugPowerState(powerState)
                        }
                    }
                }
                Menu("Wi-Fi") {
                    ForEach(DebugWiFiState.allCases) { wifiState in
                        Button(wifiState.rawValue) {
                            statusStore.applyDebugWiFiState(wifiState)
                        }
                    }
                }
                Menu("Bluetooth") {
                    ForEach(DebugBluetoothState.allCases) { bluetoothState in
                        Button(bluetoothState.rawValue) {
                            statusStore.applyDebugBluetoothState(bluetoothState)
                        }
                    }
                }
                Divider()
                Button("Restore Live Data") {
                    statusStore.restoreLiveStatus()
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 6)
        .frame(height: 26)
    }
}
#endif
