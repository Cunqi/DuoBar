import AppKit
import DuoBarCore
import DuoBarKit
import SwiftUI

struct StatusPopoverView: View {
    @ObservedObject private var statusStore: SystemStatusStore
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    @AppStorage(PreferenceKeys.popoverLayout) private var popoverLayoutRaw = ""
    @StateObject private var audioSwitcher = AudioDeviceSwitcher()
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
                    animationsEnabled: false,
                    batteryColorCodingEnabled: batteryColorCoding
                )
            }
            .padding(.horizontal, 2)

            ForEach(popoverLayout.visibleModules) { module in
                moduleView(module)
            }

            // Development diagnostics belong in the dedicated DEBUG diagnostics
            // surface, never in the production status-card hierarchy.
            Divider()

            HStack(spacing: 6) {
                settingsAction

                Spacer()

                Button(localized("Quit DuoBar")) {
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
            audioSwitcher.start()
        }
        .onDisappear { audioSwitcher.stop() }
    }

    private var popoverLayout: PopoverLayout {
        PopoverLayout.resolve(
            stored: popoverLayoutRaw,
            hasBattery: statusStore.deviceContext.ringBehavior == .batteryRing
        )
    }

    @ViewBuilder
    private func moduleView(_ module: PopoverModule) -> some View {
        switch module {
        case .network:
            NetworkStatusSection(
                symbol: networkSymbol,
                symbolVariableValue: networkSymbolVariableValue,
                detail: networkDetail,
                stateText: networkState,
                currentSSID: statusStore.status.network.ssid,
                canBrowseNetworks: statusStore.status.network.isWiFiPoweredOn == true,
                trailing: wifiPowerToggle
            )
        case .volume:
            VolumeStatusRow(
                volume: statusStore.status.audio.volume,
                hasOutputDevice: statusStore.status.audio.defaultOutput != nil,
                playbackDeviceIdentifier: statusStore.status.audio.defaultOutput?.uid,
                onSetVolume: statusStore.setVolume,
                onSetMuted: statusStore.setMuted
            )
        case .battery:
            BatteryStatusRow(
                battery: statusStore.status.battery,
                showPercentage: showBatteryPercentage
            )
        case .audioOutput:
            AudioOutputSection(symbol: audioOutputSymbol, detail: audioOutputDetail, stateText: audioOutputState, switcher: audioSwitcher)
        case .audioInput:
            AudioInputSection(switcher: audioSwitcher)
        case .systemLoad:
            SystemLoadRow()
        case .keepAwake:
            KeepAwakeRow()
        case .diskSpace:
            DiskSpaceRow()
        }
    }

    @ViewBuilder
    private var settingsAction: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                settingsLabel
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                NSApp.activate(ignoringOtherApps: true)
                onClose()
            })
        } else {
            Button(action: openSettingsFromApplicationMenu) {
                settingsLabel
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsLabel: some View {
        Label(localized("Settings"), systemImage: "gearshape")
    }

    private func openSettingsFromApplicationMenu() {
        NSApp.activate(ignoringOtherApps: true)
        if let settingsItem = findSettingsMenuItem(in: NSApp.mainMenu), let action = settingsItem.action {
            NSApp.sendAction(action, to: settingsItem.target, from: settingsItem)
        }
        onClose()
    }

    private func findSettingsMenuItem(in menu: NSMenu?) -> NSMenuItem? {
        guard let menu else { return nil }
        for item in menu.items {
            if item.keyEquivalent == ",", item.keyEquivalentModifierMask.contains(.command) {
                return item
            }
            if let settingsItem = findSettingsMenuItem(in: item.submenu) {
                return settingsItem
            }
        }
        return nil
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

    private var networkSymbolVariableValue: Double? {
        networkSymbol == "wifi" ? statusStore.status.network.wifiSignalLevel.symbolVariableValue : nil
    }

    private var networkDetail: String {
        let network = statusStore.status.network
        if statusStore.wifiPowerControlError != nil {
            return localized("Unable to change Wi-Fi power")
        }
        guard network.isAvailable else { return localized("No network interface") }
        guard network.isConnected else {
            return network.isWiFiPoweredOn == false ? localized("Wi-Fi disabled") : localized("Not connected")
        }
        switch network.transport {
        case .wifi: return network.ssid ?? localized("Network name unavailable")
        case .ethernet: return network.interfaceName ?? localized("Wired connection")
        case .other: return network.interfaceName ?? localized("Active connection")
        case .none: return localized("Not connected")
        }
    }

    private var networkState: String {
        let network = statusStore.status.network
        guard network.isAvailable else { return localized("Unavailable") }
        if network.isWiFiPoweredOn == false, !network.isConnected { return localized("Off") }
        guard network.isConnected else { return localized("Offline") }
        switch network.transport {
        case .wifi: return localized("Wi-Fi")
        case .ethernet: return localized("Ethernet")
        case .other: return localized("Connected")
        case .none: return localized("Offline")
        }
    }

    private var wifiPowerToggle: AnyView? {
        guard let wifiPowerState = statusStore.status.network.isWiFiPoweredOn else { return nil }
        return AnyView(
            Toggle(localized("Wi-Fi power"), isOn: Binding(
                get: { wifiPowerState },
                set: { statusStore.setWiFiPower($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .accessibilityLabel(localized("Wi-Fi power"))
        )
    }

    private var audioOutputSymbol: String {
        guard let output = statusStore.status.audio.defaultOutput else { return "speaker.slash" }
        if output.transport.isBluetooth {
            return output.temporaryGlyph == .airPods ? "airpodspro" : "headphones"
        }
        return "speaker.wave.2"
    }

    private var audioOutputDetail: String {
        statusStore.status.audio.defaultOutput?.name ?? localized("No output device")
    }

    private var audioOutputState: String {
        guard let output = statusStore.status.audio.defaultOutput else { return localized("Unavailable") }
        if output.transport.isBluetooth {
            return output.temporaryGlyph == .airPods ? localized("AirPods") : localized("Bluetooth")
        }
        switch output.transport {
        case .builtIn: return localized("Built-in")
        case .airPlay: return localized("AirPlay")
        case .usb: return localized("USB")
        case .hdmi, .displayPort: return localized("Display")
        case .virtual: return localized("Virtual")
        case .bluetooth, .bluetoothLE: return localized("Bluetooth")
        case .other: return localized("Connected")
        }
    }
}
