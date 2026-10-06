import Foundation

public enum BatteryBoltPlacement: Equatable, Sendable {
    case none
    case topGap
}

public enum BatteryRingColorRole: Equatable, Sendable {
    case monochrome
    case charging
    case lowPowerMode
    case lowBattery
}

public struct BatteryRingPresentation: Equatable, Sendable {
    public init(
        boltPlacement: BatteryBoltPlacement,
        colorRole: BatteryRingColorRole
    ) {
        self.boltPlacement = boltPlacement
        self.colorRole = colorRole
    }

    public let boltPlacement: BatteryBoltPlacement
    public let colorRole: BatteryRingColorRole

    public static func resolve(
        battery: BatteryStatus,
        colorCodingEnabled: Bool
    ) -> BatteryRingPresentation {
        guard battery.isAvailable else {
            return BatteryRingPresentation(boltPlacement: .none, colorRole: .monochrome)
        }

        let boltPlacement: BatteryBoltPlacement = battery.isPluggedIn ? .topGap : .none

        guard colorCodingEnabled else {
            return BatteryRingPresentation(boltPlacement: boltPlacement, colorRole: .monochrome)
        }

        let colorRole: BatteryRingColorRole
        if battery.isPluggedIn {
            colorRole = .charging
        } else if battery.isLowPowerModeEnabled {
            colorRole = .lowPowerMode
        } else if let percentage = battery.percentage, percentage < 20 {
            colorRole = .lowBattery
        } else {
            colorRole = .monochrome
        }
        return BatteryRingPresentation(boltPlacement: boltPlacement, colorRole: colorRole)
    }
}
