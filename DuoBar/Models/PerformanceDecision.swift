import Foundation

enum PerformanceMetric: String, CaseIterable, Sendable {
    case idle
    case cpu
    case memory
    case thermal
}

enum PerformanceSeverity: Int, Comparable, Sendable {
    case idle
    case normal
    case elevated
    case serious
    case critical

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum PerformanceDecisionReason: String, Sendable {
    case baseline = "No sustained performance condition"
    case cpuSustained = "Sustained CPU workload"
    case memoryHeadroom = "Sustained memory pressure estimate"
    case memoryCritical = "Critical memory pressure estimate"
    case thermalFair = "Elevated thermal state"
    case thermalSerious = "Serious thermal state"
    case thermalCritical = "Critical thermal state"
    case candidatePending = "Candidate awaiting persistence threshold"
    case minimumHold = "Current metric retained for minimum hold time"
    case hysteresis = "Current metric retained by hysteresis"
    case releasePending = "Condition cleared; release delay active"
}

struct PerformanceCandidate: Equatable, Sendable {
    var metric: PerformanceMetric
    var severity: PerformanceSeverity
    var normalizedValue: Double
    var reason: PerformanceDecisionReason

    static let idle = PerformanceCandidate(
        metric: .idle,
        severity: .idle,
        normalizedValue: 0,
        reason: .baseline
    )
}

struct PerformanceDecision: Equatable, Sendable {
    var activeMetric: PerformanceMetric
    var severity: PerformanceSeverity
    var normalizedRingValue: Double
    var reason: PerformanceDecisionReason
    var candidate: PerformanceCandidate

    static let idle = PerformanceDecision(
        activeMetric: .idle,
        severity: .idle,
        normalizedRingValue: 0,
        reason: .baseline,
        candidate: .idle
    )
}
