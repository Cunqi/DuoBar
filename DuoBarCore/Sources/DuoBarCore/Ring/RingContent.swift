import Foundation

public enum RingContent: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case battery
    case brightness
    case cpu
    case memory
    case thermal
    case volume

    public static let defaultValue = RingContent.automatic

    public var id: Self { self }

    public var isFixedMetric: Bool {
        self != .automatic && self != .battery
    }


    public static func options(hasBattery: Bool) -> [RingContent] {
        allCases.filter { hasBattery || $0 != .battery }
    }

}

public enum RingDisplay: Equatable, Sendable {
    case battery
    case adaptive(AdaptiveRingState)

    public var adaptiveState: AdaptiveRingState? {
        guard case let .adaptive(state) = self else { return nil }
        return state
    }
}

public struct RingContentInputs: Equatable, Sendable {
    public init(
        hasBattery: Bool,
        allowsPressureOverride: Bool,
        automaticState: AdaptiveRingState,
        performanceSnapshot: PerformanceSnapshot?,
        brightnessSnapshot: DisplayBrightnessSnapshot?,
        volume: OutputVolumeStatus,
        timestamp: TimeInterval
    ) {
        self.hasBattery = hasBattery
        self.allowsPressureOverride = allowsPressureOverride
        self.automaticState = automaticState
        self.performanceSnapshot = performanceSnapshot
        self.brightnessSnapshot = brightnessSnapshot
        self.volume = volume
        self.timestamp = timestamp
    }

    public var hasBattery: Bool
    public var allowsPressureOverride: Bool
    public var automaticState: AdaptiveRingState
    public var performanceSnapshot: PerformanceSnapshot?
    public var brightnessSnapshot: DisplayBrightnessSnapshot?
    public var volume: OutputVolumeStatus
    public var timestamp: TimeInterval
}

public enum RingContentResolver {
    public static let brightnessMaximumAge: TimeInterval = 4

    public static func resolve(content: RingContent, inputs: RingContentInputs) -> RingDisplay {
        switch content {
        case .automatic, .battery:
            return inputs.hasBattery ? .battery : .adaptive(inputs.automaticState)
        case .brightness, .cpu, .memory, .thermal, .volume:
            if inputs.allowsPressureOverride, case .performance = inputs.automaticState {
                return .adaptive(inputs.automaticState)
            }
            return .adaptive(fixedState(for: content, inputs: inputs))
        }
    }

    public static func needsMonitoring(content: RingContent, hasBattery: Bool) -> Bool {
        switch content {
        case .automatic, .battery: !hasBattery
        case .brightness, .cpu, .memory, .thermal, .volume: true
        }
    }

    public static func thermalValue(for state: PerformanceThermalState) -> Double {
        switch state {
        case .nominal: 0.25
        case .fair: 0.55
        case .serious: 0.82
        case .critical: 1
        }
    }

    private static func fixedState(for content: RingContent, inputs: RingContentInputs) -> AdaptiveRingState {
        switch content {
        case .brightness:
            guard let snapshot = inputs.brightnessSnapshot,
                  snapshot.isFresh(at: inputs.timestamp, maximumAge: brightnessMaximumAge),
                  case let .available(value) = snapshot.availability
            else { return .neutral }
            return .brightness(clamp(value))
        case .cpu:
            guard let load = inputs.performanceSnapshot?.cpuLoad else { return .neutral }
            return .performance(metric: .cpu, value: clamp(load))
        case .memory:
            guard let memory = inputs.performanceSnapshot?.memory else { return .neutral }
            return .performance(metric: .memory, value: clamp(1 - memory.availableHeadroom))
        case .thermal:
            guard let snapshot = inputs.performanceSnapshot else { return .neutral }
            return .performance(metric: .thermal, value: thermalValue(for: snapshot.thermalState))
        case .volume:
            if inputs.volume.isMuted { return .volume(0) }
            guard let level = inputs.volume.level else { return .neutral }
            return .volume(clamp(level))
        case .automatic, .battery:
            return inputs.automaticState
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

public enum RingReading: Equatable, Sendable {
    case battery(percent: Int)
    case brightness(percent: Int)
    case cpu(percent: Int)
    case memory(percent: Int)
    case thermal(PerformanceThermalState)
    case volume(percent: Int)
    case unavailable

    public init(display: RingDisplay, snapshot: PerformanceSnapshot?, batteryPercentage: Int?) {
        switch display {
        case .battery:
            self = batteryPercentage.map { .battery(percent: $0) } ?? .unavailable
        case .adaptive(.neutral):
            self = .unavailable
        case let .adaptive(.brightness(value)):
            self = .brightness(percent: Self.percent(value))
        case let .adaptive(.volume(value)):
            self = .volume(percent: Self.percent(value))
        case let .adaptive(.performance(metric, value)):
            switch metric {
            case .cpu:
                self = .cpu(percent: Self.percent(snapshot?.cpuLoad ?? value))
            case .memory:
                let used = snapshot?.memory.map { 1 - $0.availableHeadroom } ?? value
                self = .memory(percent: Self.percent(used))
            case .thermal:
                self = snapshot.map { .thermal($0.thermalState) } ?? .unavailable
            case .idle:
                self = .unavailable
            }
        }
    }



    private static func percent(_ value: Double) -> Int {
        Int((min(max(value, 0), 1) * 100).rounded())
    }
}
