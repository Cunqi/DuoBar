import Foundation

struct PerformanceDecisionThresholds: Equatable, Sendable {
    var cpuActivation: Double = 0.55
    var cpuSerious: Double = 0.82
    var cpuCritical: Double = 0.95
    var activationDuration: TimeInterval = 4
    var switchDuration: TimeInterval = 5
    var minimumHoldDuration: TimeInterval = 8
    var releaseDelay: TimeInterval = 6
    var switchSeverityMargin: Int = 1
}

struct PerformanceDecisionEngine: Sendable {
    private(set) var decision: PerformanceDecision = .idle
    let thresholds: PerformanceDecisionThresholds

    private var activeSince: TimeInterval?
    private var pendingCandidate: PerformanceCandidate?
    private var pendingSince: TimeInterval?
    private var releaseSince: TimeInterval?

    init(thresholds: PerformanceDecisionThresholds = .init()) {
        self.thresholds = thresholds
    }

    mutating func update(with snapshot: PerformanceSnapshot) -> PerformanceDecision {
        let candidate = candidate(for: snapshot)
        let now = snapshot.timestamp

        if candidate.metric == decision.activeMetric, candidate.metric != .idle {
            clearPending()
            releaseSince = nil
            decision = PerformanceDecision(
                activeMetric: candidate.metric,
                severity: candidate.severity,
                normalizedRingValue: candidate.normalizedValue,
                reason: candidate.reason,
                candidate: candidate
            )
            return decision
        }

        if isCriticalOverride(candidate) {
            activate(candidate, at: now)
            return decision
        }

        if decision.activeMetric == .idle {
            guard candidate.metric != .idle else {
                clearPending()
                decision = .idle
                return decision
            }

            track(candidate, at: now)
            if pendingDuration(at: now) >= thresholds.activationDuration {
                activate(candidate, at: now)
            } else {
                decision = PerformanceDecision(
                    activeMetric: .idle,
                    severity: .idle,
                    normalizedRingValue: 0,
                    reason: .candidatePending,
                    candidate: candidate
                )
            }
            return decision
        }

        let heldFor = now - (activeSince ?? now)
        if candidate.metric == .idle {
            clearPending()
            if releaseSince == nil { releaseSince = now }
            if heldFor >= thresholds.minimumHoldDuration,
               now - (releaseSince ?? now) >= thresholds.releaseDelay {
                transitionToIdle()
            } else {
                decision.reason = heldFor < thresholds.minimumHoldDuration ? .minimumHold : .releasePending
                decision.candidate = candidate
            }
            return decision
        }

        releaseSince = nil
        let severityAdvantage = candidate.severity.rawValue - decision.severity.rawValue
        guard heldFor >= thresholds.minimumHoldDuration else {
            clearPending()
            decision.reason = .minimumHold
            decision.candidate = candidate
            return decision
        }
        guard severityAdvantage >= thresholds.switchSeverityMargin else {
            clearPending()
            decision.reason = .hysteresis
            decision.candidate = candidate
            return decision
        }

        track(candidate, at: now)
        if pendingDuration(at: now) >= thresholds.switchDuration {
            activate(candidate, at: now)
        } else {
            decision.reason = .candidatePending
            decision.candidate = candidate
        }
        return decision
    }

    func candidate(for snapshot: PerformanceSnapshot) -> PerformanceCandidate {
        let thermal = thermalCandidate(snapshot.thermalState)
        if thermal.severity >= .serious { return thermal }

        let memory = memoryCandidate(snapshot.memory)
        if memory.severity == .critical { return memory }

        let cpu = cpuCandidate(snapshot.cpuLoad)
        let candidates = [thermal, memory, cpu].filter { $0.metric != .idle }
        return candidates.max { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity < rhs.severity }
            return relevanceRank(lhs.metric) < relevanceRank(rhs.metric)
        } ?? .idle
    }

    private func cpuCandidate(_ load: Double?) -> PerformanceCandidate {
        guard let load, load >= thresholds.cpuActivation else { return .idle }
        let severity: PerformanceSeverity
        if load >= thresholds.cpuCritical {
            severity = .critical
        } else if load >= thresholds.cpuSerious {
            severity = .serious
        } else {
            severity = .elevated
        }
        return PerformanceCandidate(metric: .cpu, severity: severity, normalizedValue: clamp(load), reason: .cpuSustained)
    }

    private func memoryCandidate(_ memory: MemorySnapshot?) -> PerformanceCandidate {
        guard let memory else { return .idle }
        switch memory.stress {
        case .normal:
            return .idle
        case .elevated:
            return PerformanceCandidate(metric: .memory, severity: .elevated, normalizedValue: 0.58, reason: .memoryHeadroom)
        case .serious:
            return PerformanceCandidate(metric: .memory, severity: .serious, normalizedValue: 0.8, reason: .memoryHeadroom)
        case .critical:
            return PerformanceCandidate(metric: .memory, severity: .critical, normalizedValue: 1, reason: .memoryCritical)
        }
    }

    private func thermalCandidate(_ state: PerformanceThermalState) -> PerformanceCandidate {
        switch state {
        case .nominal:
            return .idle
        case .fair:
            return PerformanceCandidate(metric: .thermal, severity: .elevated, normalizedValue: 0.55, reason: .thermalFair)
        case .serious:
            return PerformanceCandidate(metric: .thermal, severity: .serious, normalizedValue: 0.82, reason: .thermalSerious)
        case .critical:
            return PerformanceCandidate(metric: .thermal, severity: .critical, normalizedValue: 1, reason: .thermalCritical)
        }
    }

    private func isCriticalOverride(_ candidate: PerformanceCandidate) -> Bool {
        (candidate.metric == .memory && candidate.severity == .critical)
            || (candidate.metric == .thermal && candidate.severity >= .serious)
    }

    private func relevanceRank(_ metric: PerformanceMetric) -> Int {
        switch metric {
        case .idle: 0
        case .cpu: 1
        case .memory: 2
        case .thermal: 3
        }
    }

    private mutating func track(_ candidate: PerformanceCandidate, at timestamp: TimeInterval) {
        guard pendingCandidate?.metric != candidate.metric else { return }
        pendingCandidate = candidate
        pendingSince = timestamp
    }

    private func pendingDuration(at timestamp: TimeInterval) -> TimeInterval {
        timestamp - (pendingSince ?? timestamp)
    }

    private mutating func activate(_ candidate: PerformanceCandidate, at timestamp: TimeInterval) {
        decision = PerformanceDecision(
            activeMetric: candidate.metric,
            severity: candidate.severity,
            normalizedRingValue: candidate.normalizedValue,
            reason: candidate.reason,
            candidate: candidate
        )
        activeSince = timestamp
        releaseSince = nil
        clearPending()
    }

    private mutating func transitionToIdle() {
        decision = .idle
        activeSince = nil
        releaseSince = nil
        clearPending()
    }

    private mutating func clearPending() {
        pendingCandidate = nil
        pendingSince = nil
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
