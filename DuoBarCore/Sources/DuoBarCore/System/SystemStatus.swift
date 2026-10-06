import Foundation

public struct BluetoothStatus: Equatable, Sendable {
    public init(
        isAvailable: Bool,
        isPoweredOn: Bool
    ) {
        self.isAvailable = isAvailable
        self.isPoweredOn = isPoweredOn
    }

    public var isAvailable: Bool
    public var isPoweredOn: Bool

    public static let unavailable = BluetoothStatus(isAvailable: false, isPoweredOn: false)
}
public struct SystemStatus: Equatable, Sendable {
    public init(
        battery: BatteryStatus,
        network: NetworkStatus,
        audio: AudioStatus,
        bluetooth: BluetoothStatus
    ) {
        self.battery = battery
        self.network = network
        self.audio = audio
        self.bluetooth = bluetooth
    }

    public var battery: BatteryStatus
    public var network: NetworkStatus
    public var audio: AudioStatus
    // Retained until Core Audio connection behavior is validated on real hardware.
    public var bluetooth: BluetoothStatus

    public static let unavailable = SystemStatus(
        battery: .unavailable,
        network: .unavailable,
        audio: .unavailable,
        bluetooth: .unavailable
    )
}
