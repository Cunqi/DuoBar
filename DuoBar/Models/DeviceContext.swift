import Foundation

struct DeviceContext: Equatable, Sendable {
    enum PerformanceBehavior: String, Sendable {
        case batteryRing
        case performanceRing
    }

    let hasInternalBattery: Bool

    var performanceBehavior: PerformanceBehavior {
        hasInternalBattery ? .batteryRing : .performanceRing
    }
}
