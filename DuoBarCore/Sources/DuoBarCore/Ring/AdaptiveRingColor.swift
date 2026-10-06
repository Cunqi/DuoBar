import Foundation


public enum AdaptiveRingColorRole: String, Equatable {
    case monochrome
    case cpu
    case memory
    case thermal
}

public struct AdaptiveRingColorPresentation: Equatable {
    public init(
        role: AdaptiveRingColorRole,
        intensity: Double
    ) {
        self.role = role
        self.intensity = intensity
    }

    public let role: AdaptiveRingColorRole
    public let intensity: Double

}

public enum AdaptiveRingColorResolver {
    public static func resolve(
        state: AdaptiveRingState,
        decision: PerformanceDecision,
        colorCodingEnabled: Bool
    ) -> AdaptiveRingColorPresentation {
        guard colorCodingEnabled,
              case .performance(let metric, _) = state,
              metric == decision.activeMetric
        else { return AdaptiveRingColorPresentation(role: .monochrome, intensity: 1) }

        let role: AdaptiveRingColorRole
        switch metric {
        case .cpu: role = .cpu
        case .memory: role = .memory
        case .thermal: role = .thermal
        case .idle: return AdaptiveRingColorPresentation(role: .monochrome, intensity: 1)
        }
        return AdaptiveRingColorPresentation(role: role, intensity: intensity(for: decision.severity))
    }

    public static func intensity(for severity: PerformanceSeverity) -> Double {
        switch severity {
        case .idle, .normal: 0.60
        case .elevated: 0.68
        case .serious: 0.82
        case .critical: 1.0
        }
    }
}
