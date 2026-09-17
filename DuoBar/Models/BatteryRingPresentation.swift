import Foundation

enum BatteryBoltPlacement: Equatable, Sendable {
    case none
    case ringEndpoint
    case ringMidpoint
}

enum BatteryRingColorRole: Equatable, Sendable {
    case monochrome
    case charging
    case lowPowerMode
    case lowBattery
}

struct BatteryRingPresentation: Equatable, Sendable {
    let boltPlacement: BatteryBoltPlacement
    let colorRole: BatteryRingColorRole

    static func resolve(
        battery: BatteryStatus,
        colorCodingEnabled: Bool
    ) -> BatteryRingPresentation {
        guard battery.isAvailable else {
            return BatteryRingPresentation(boltPlacement: .none, colorRole: .monochrome)
        }

        let boltPlacement: BatteryBoltPlacement
        if battery.isFullyCharged && battery.isPluggedIn {
            boltPlacement = .ringMidpoint
        } else if battery.isCharging {
            boltPlacement = .ringEndpoint
        } else {
            boltPlacement = .none
        }

        guard colorCodingEnabled else {
            return BatteryRingPresentation(boltPlacement: boltPlacement, colorRole: .monochrome)
        }

        let colorRole: BatteryRingColorRole
        if battery.isFullyCharged && battery.isPluggedIn {
            colorRole = .monochrome
        } else if battery.isCharging {
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
