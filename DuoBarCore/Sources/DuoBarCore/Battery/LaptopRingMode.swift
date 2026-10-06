import Foundation

/// The top-level ring choice for a Mac with an internal battery.
/// This is intentionally independent from Adaptive Ring telemetry and rendering.
public enum LaptopRingMode: Equatable, Sendable {
    case battery
    case adaptive
}

/// The supported delay choices for a fully charged, plugged-in MacBook.
/// Settings can persist this typed value in a later phase.
public enum LaptopAdaptiveFullChargeDelay: String, CaseIterable, Equatable, Sendable {
    case immediately
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour

    public static let `default`: Self = .fifteenMinutes

    public var timeInterval: TimeInterval {
        switch self {
        case .immediately: 0
        case .fiveMinutes: 5 * 60
        case .fifteenMinutes: 15 * 60
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        }
    }
}

/// Read-only diagnostic state for the future MacBook Battery → Adaptive integration.
public struct LaptopRingModeState: Equatable, Sendable {
    public init(
        mode: LaptopRingMode,
        sessionStartPercentage: Int?,
        targetPercentage: Int?,
        isWaitingForFullChargeDelay: Bool
    ) {
        self.mode = mode
        self.sessionStartPercentage = sessionStartPercentage
        self.targetPercentage = targetPercentage
        self.isWaitingForFullChargeDelay = isWaitingForFullChargeDelay
    }

    public let mode: LaptopRingMode
    public let sessionStartPercentage: Int?
    public let targetPercentage: Int?
    public let isWaitingForFullChargeDelay: Bool

    public static let battery = LaptopRingModeState(
        mode: .battery,
        sessionStartPercentage: nil,
        targetPercentage: nil,
        isWaitingForFullChargeDelay: false
    )
}
