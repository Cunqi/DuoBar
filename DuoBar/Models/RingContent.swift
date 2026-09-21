import Foundation

enum RingContent: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case battery
    case brightness
    case cpu
    case memory
    case thermal
    case volume

    static let defaultValue = RingContent.automatic

    var id: Self { self }

    var isFixedMetric: Bool {
        self != .automatic && self != .battery
    }

    var localizedDisplayName: String {
        switch self {
        case .automatic: localized("Automatic")
        case .battery: localized("Battery")
        case .brightness: localized("Brightness")
        case .cpu: localized("CPU")
        case .memory: localized("Memory")
        case .thermal: localized("Thermal")
        case .volume: localized("Volume")
        }
    }

    static func options(hasBattery: Bool) -> [RingContent] {
        allCases.filter { hasBattery || $0 != .battery }
    }

    static func stored(in defaults: UserDefaults = .standard) -> RingContent {
        defaults.string(forKey: PreferenceKeys.ringContent).flatMap(RingContent.init(rawValue:)) ?? defaultValue
    }
}

enum RingDisplay: Equatable, Sendable {
    case battery
    case adaptive(AdaptiveRingState)

    var adaptiveState: AdaptiveRingState? {
        guard case let .adaptive(state) = self else { return nil }
        return state
    }
}

struct RingContentInputs: Equatable, Sendable {
    var hasBattery: Bool
    var allowsPressureOverride: Bool
    var automaticState: AdaptiveRingState
    var performanceSnapshot: PerformanceSnapshot?
    var brightnessSnapshot: DisplayBrightnessSnapshot?
    var volume: OutputVolumeStatus
    var timestamp: TimeInterval
}

enum RingContentResolver {
    static let brightnessMaximumAge: TimeInterval = 4

    static func resolve(content: RingContent, inputs: RingContentInputs) -> RingDisplay {
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

    static func needsMonitoring(content: RingContent, hasBattery: Bool) -> Bool {
        switch content {
        case .automatic, .battery: !hasBattery
        case .brightness, .cpu, .memory, .thermal, .volume: true
        }
    }

    static func thermalValue(for state: PerformanceThermalState) -> Double {
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

enum RingReading: Equatable, Sendable {
    case battery(percent: Int)
    case brightness(percent: Int)
    case cpu(percent: Int)
    case memory(percent: Int)
    case thermal(PerformanceThermalState)
    case volume(percent: Int)
    case unavailable

    init(display: RingDisplay, snapshot: PerformanceSnapshot?, batteryPercentage: Int?) {
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

    var localizedDescription: String {
        switch self {
        case let .battery(percent): localized("%@ %d%%", localized("Battery"), percent)
        case let .brightness(percent): localized("%@ %d%%", localized("Brightness"), percent)
        case let .cpu(percent): localized("%@ %d%%", localized("CPU"), percent)
        case let .memory(percent): localized("%@ %d%%", localized("Memory"), percent)
        case let .volume(percent): localized("%@ %d%%", localized("Volume"), percent)
        case let .thermal(state): localized("%@ %@", localized("Thermal"), Self.thermalLabel(for: state))
        case .unavailable: localized("No data")
        }
    }

    static func thermalLabel(for state: PerformanceThermalState) -> String {
        switch state {
        case .nominal: localized("Thermal Nominal")
        case .fair: localized("Thermal Fair")
        case .serious: localized("Thermal Serious")
        case .critical: localized("Thermal Critical")
        }
    }

    private static func percent(_ value: Double) -> Int {
        Int((min(max(value, 0), 1) * 100).rounded())
    }
}

enum StatusHoverText {
    static func text(ring: RingReading, network: NetworkStatus, volume: OutputVolumeStatus) -> String {
        [
            localized("Ring: %@", ring.localizedDescription),
            localized("Network: %@", networkDescription(network)),
            localized("Volume: %@", volumeDescription(volume))
        ].joined(separator: "\n")
    }

    private static func networkDescription(_ network: NetworkStatus) -> String {
        guard network.isConnected else { return localized("Offline") }
        switch network.transport {
        case .wifi: return network.ssid ?? localized("Wi-Fi")
        case .ethernet: return localized("Ethernet")
        case .other: return localized("Connected")
        case .none: return localized("Offline")
        }
    }

    private static func volumeDescription(_ volume: OutputVolumeStatus) -> String {
        if volume.isMuted { return localized("Muted") }
        return volume.percentage.map { localized("%d%%", $0) } ?? localized("No data")
    }
}
