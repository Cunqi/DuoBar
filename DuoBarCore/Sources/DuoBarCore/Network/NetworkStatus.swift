import Foundation

public enum NetworkTransport: Equatable, Sendable {
    case wifi
    case ethernet
    case other
    case none
}
public struct NetworkStatus: Equatable, Sendable {
    public init(
        isAvailable: Bool,
        isConnected: Bool,
        transport: NetworkTransport,
        interfaceName: String?,
        isWiFiPoweredOn: Bool?,
        ssid: String?,
        rssi: Int?
    ) {
        self.isAvailable = isAvailable
        self.isConnected = isConnected
        self.transport = transport
        self.interfaceName = interfaceName
        self.isWiFiPoweredOn = isWiFiPoweredOn
        self.ssid = ssid
        self.rssi = rssi
    }

    public var isAvailable: Bool
    public var isConnected: Bool
    public var transport: NetworkTransport
    public var interfaceName: String?
    public var isWiFiPoweredOn: Bool?
    public var ssid: String?
    public var rssi: Int?

    public static let unavailable = NetworkStatus(
        isAvailable: false,
        isConnected: false,
        transport: .none,
        interfaceName: nil,
        isWiFiPoweredOn: nil,
        ssid: nil,
        rssi: nil
    )

    public var signalStrength: Double? {
        guard let rssi, rssi < 0 else { return nil }
        return min(max(Double(rssi + 100) / 65.0, 0), 1)
    }

    public var wifiSignalLevel: WiFiSignalLevel {
        guard isAvailable else { return .unavailable }
        guard transport == .wifi || !isConnected else { return .unavailable }
        guard isWiFiPoweredOn != false else { return .disabled }
        guard isConnected else { return .disconnected }

        return WiFiSignalLevel(rssi: rssi)
    }
}
public enum WiFiSignalLevel: Hashable, Sendable {
    case strong
    case medium
    case weak
    case disconnected
    case disabled
    case unavailable

    public init(rssi: Int?) {
        guard let rssi, rssi < 0 else {
            self = .medium
            return
        }
        if rssi >= -67 {
            self = .strong
        } else if rssi >= -75 {
            self = .medium
        } else {
            self = .weak
        }
    }

    public var symbolVariableValue: Double? {
        switch self {
        case .strong: 1
        case .medium: 0.62
        case .weak: 0.25
        case .disconnected, .disabled, .unavailable: nil
        }
    }
}
