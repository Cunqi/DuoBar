import Foundation

public enum AdaptiveRingState: Equatable, Sendable {
    case brightness(Double)
    case volume(Double)
    case neutral
    case performance(metric: PerformanceMetric, value: Double)

    public var normalizedRingValue: Double? {
        switch self {
        case .brightness(let value), .volume(let value), .performance(_, let value): value
        case .neutral: nil
        }
    }

    public var diagnosticLabel: String {
        switch self {
        case .brightness: "Brightness"
        case .volume: "Volume"
        case .neutral: "Neutral"
        case .performance(let metric, _): "Performance · \(metric.rawValue.capitalized)"
        }
    }
}

public struct AdaptiveRingCoordinator: Sendable {
    public init(
        brightnessMaximumAge: TimeInterval = 4
    ) {
        self.brightnessMaximumAge = brightnessMaximumAge
    }

    public var brightnessMaximumAge: TimeInterval = 4

    public func resolve(
        brightness: DisplayBrightnessSnapshot,
        performance: PerformanceDecision,
        at timestamp: TimeInterval
    ) -> AdaptiveRingState {
        if performance.activeMetric != .idle {
            return .performance(
                metric: performance.activeMetric,
                value: clamp(performance.normalizedRingValue)
            )
        }

        guard brightness.isFresh(at: timestamp, maximumAge: brightnessMaximumAge) else {
            return .neutral
        }
        switch brightness.availability {
        case .available(let value):
            return .brightness(clamp(value))
        case .unavailable:
            return .neutral
        }
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

public enum AdaptiveRingTransitionKind: Equatable, Sendable {
    case none
    case baselineUpdate
    case performanceTakeover
    case performanceValueUpdate
    case performanceMetricChange
    case baselineRelease
}

public struct AdaptiveRingPresentationTransition: Equatable, Sendable {
    public init(
        kind: AdaptiveRingTransitionKind,
        duration: TimeInterval
    ) {
        self.kind = kind
        self.duration = duration
    }

    public let kind: AdaptiveRingTransitionKind
    public let duration: TimeInterval

    public static let none = AdaptiveRingPresentationTransition(kind: .none, duration: 0)

    public func effectiveDuration(animationsEnabled: Bool, reduceMotion: Bool) -> TimeInterval {
        animationsEnabled && !reduceMotion ? duration : 0
    }
}

public enum AdaptiveRingVisualMeaning: Equatable, Sendable {
    case neutral
    case brightness
    case volume
    case performance(PerformanceMetric)
}

public struct AdaptiveRingVisualTarget: Equatable, Sendable {
    public static let neutralBaseline = 0.25

    public let meaning: AdaptiveRingVisualMeaning
    public let progress: Double

    public init(state: AdaptiveRingState) {
        switch state {
        case .neutral:
            meaning = .neutral
            progress = Self.neutralBaseline
        case .brightness(let value):
            meaning = .brightness
            progress = Self.clamp(value)
        case .volume(let value):
            meaning = .volume
            progress = Self.clamp(value)
        case .performance(let metric, let value):
            meaning = .performance(metric)
            progress = Self.clamp(value)
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

public struct AdaptiveRingPresentationState: Equatable, Sendable {
    public private(set) var adaptiveState: AdaptiveRingState
    public private(set) var displayedProgress: Double

    public init(state: AdaptiveRingState = .neutral) {
        adaptiveState = state
        displayedProgress = AdaptiveRingVisualTarget(state: state).progress
    }

    public mutating func synchronize(to state: AdaptiveRingState) {
        adaptiveState = state
        displayedProgress = AdaptiveRingVisualTarget(state: state).progress
    }

    public mutating func retarget(to state: AdaptiveRingState) -> AdaptiveRingPresentationTransition {
        let transition = AdaptiveRingPresentation.transition(from: adaptiveState, to: state)
        guard transition.kind != .none else { return .none }
        adaptiveState = state
        displayedProgress = AdaptiveRingVisualTarget(state: state).progress
        return transition
    }
}

public enum AdaptiveRingPresentation {
    public static let valueTolerance = 0.005

    public static func transition(
        from oldState: AdaptiveRingState,
        to newState: AdaptiveRingState
    ) -> AdaptiveRingPresentationTransition {
        guard isMeaningfullyDifferent(oldState, newState) else { return .none }

        switch (oldState, newState) {
        case (.performance(let oldMetric, _), .performance(let newMetric, _)):
            if oldMetric == newMetric {
                return AdaptiveRingPresentationTransition(kind: .performanceValueUpdate, duration: 0.40)
            }
            return AdaptiveRingPresentationTransition(kind: .performanceMetricChange, duration: 0.45)
        case (.performance, _):
            return AdaptiveRingPresentationTransition(kind: .baselineRelease, duration: 0.60)
        case (_, .performance):
            return AdaptiveRingPresentationTransition(kind: .performanceTakeover, duration: 0.50)
        case (.neutral, .neutral):
            return .none
        default:
            return AdaptiveRingPresentationTransition(kind: .baselineUpdate, duration: 0.40)
        }
    }

    public static func isMeaningfullyDifferent(
        _ oldState: AdaptiveRingState,
        _ newState: AdaptiveRingState
    ) -> Bool {
        switch (oldState, newState) {
        case (.neutral, .neutral):
            return false
        case (.brightness(let old), .brightness(let new)), (.volume(let old), .volume(let new)):
            return abs(old - new) >= valueTolerance
        case (.performance(let oldMetric, let old), .performance(let newMetric, let new)):
            return oldMetric != newMetric || abs(old - new) >= valueTolerance
        default:
            return true
        }
    }

    public static func metricToIdentify(
        from oldMetric: PerformanceMetric,
        to newMetric: PerformanceMetric,
        hasHigherPriorityEvent: Bool
    ) -> PerformanceMetric? {
        guard !hasHigherPriorityEvent,
              newMetric != .idle,
              newMetric != oldMetric
        else { return nil }
        return newMetric
    }
}

public enum AdaptiveRingDiagnosticFormatter {
    public static func visualTarget(_ state: AdaptiveRingState) -> String {
        let target = AdaptiveRingVisualTarget(state: state)
        switch target.meaning {
        case .neutral:
            return "Neutral baseline · \(percentage(target.progress))"
        case .brightness:
            return "Brightness · \(percentage(target.progress))"
        case .volume:
            return "Volume · \(percentage(target.progress))"
        case .performance(let metric):
            return "\(metric.rawValue.capitalized) · \(percentage(target.progress))"
        }
    }

    private static func percentage(_ value: Double) -> String {
        String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), value * 100)
    }
}
