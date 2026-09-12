#if DEBUG
import Foundation

enum DebugBatteryLevel: Int, CaseIterable, Identifiable {
    case full = 100
    case seventyFive = 75
    case half = 50
    case twentyFive = 25
    case low = 10

    var id: Int { rawValue }
    var title: String { "\(rawValue)%" }
}

enum DebugPowerState: String, CaseIterable, Identifiable {
    case charging = "Charging"
    case notCharging = "Not Charging"

    var id: String { rawValue }
    var isCharging: Bool { self == .charging }
}

enum DebugWiFiState: String, CaseIterable, Identifiable {
    case strong = "Strong"
    case medium = "Medium"
    case weak = "Weak"
    case disconnected = "Disconnected"
    case disabled = "Disabled"

    var id: String { rawValue }

    var status: WiFiStatus {
        switch self {
        case .strong:
            WiFiStatus(isAvailable: true, isPoweredOn: true, isConnected: true, ssid: "Debug Strong", rssi: -42)
        case .medium:
            WiFiStatus(isAvailable: true, isPoweredOn: true, isConnected: true, ssid: "Debug Medium", rssi: -67)
        case .weak:
            WiFiStatus(isAvailable: true, isPoweredOn: true, isConnected: true, ssid: "Debug Weak", rssi: -84)
        case .disconnected:
            WiFiStatus(isAvailable: true, isPoweredOn: true, isConnected: false, ssid: nil, rssi: nil)
        case .disabled:
            WiFiStatus(isAvailable: true, isPoweredOn: false, isConnected: false, ssid: nil, rssi: nil)
        }
    }
}

enum DebugBluetoothState: String, CaseIterable, Identifiable {
    case on = "On"
    case off = "Off"
    case unavailable = "Unavailable"

    var id: String { rawValue }

    var status: BluetoothStatus {
        switch self {
        case .on:
            BluetoothStatus(isAvailable: true, isPoweredOn: true)
        case .off:
            BluetoothStatus(isAvailable: true, isPoweredOn: false)
        case .unavailable:
            BluetoothStatus(isAvailable: false, isPoweredOn: false)
        }
    }
}
#endif
