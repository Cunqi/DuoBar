import Foundation

public struct BatteryStatus: Equatable, Sendable {
    public init(
        percentage: Int?,
        isCharging: Bool,
        isPluggedIn: Bool,
        isFullyCharged: Bool,
        isAvailable: Bool,
        isLowPowerModeEnabled: Bool = false
    ) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.isFullyCharged = isFullyCharged
        self.isAvailable = isAvailable
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
    }

    public var percentage: Int?
    public var isCharging: Bool
    public var isPluggedIn: Bool
    public var isFullyCharged: Bool
    public var isAvailable: Bool
    public var isLowPowerModeEnabled = false

    public static let unavailable = BatteryStatus(
        percentage: nil,
        isCharging: false,
        isPluggedIn: false,
        isFullyCharged: false,
        isAvailable: false
    )
}
