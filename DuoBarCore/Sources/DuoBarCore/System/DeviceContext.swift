import Foundation

public struct DeviceContext: Equatable, Sendable {
    public init(
        hasInternalBattery: Bool
    ) {
        self.hasInternalBattery = hasInternalBattery
    }

    public enum RingBehavior: String, Sendable {
        case batteryRing
        case adaptiveRing
    }

    public let hasInternalBattery: Bool

    public var ringBehavior: RingBehavior {
        hasInternalBattery ? .batteryRing : .adaptiveRing
    }
}
