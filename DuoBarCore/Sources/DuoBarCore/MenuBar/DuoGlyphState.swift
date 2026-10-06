import Foundation

public enum DuoCenterState: Hashable {
    case wifi(WiFiSignalLevel)
    case ethernet
    case offline
    case other
    case unavailable
    case airPodsPro
    case airPodsMax
    case airPods
    case headphones
    case audioDevice
    case performanceCPU
    case performanceMemory
    case performanceThermal
}

public enum DuoSemanticFeedback: Equatable {
    case none
    case charging
    case lowBattery
    case audioConnected
}

public enum DuoPersistentRingMode: Equatable {
    case battery
    case adaptive
}

public struct DuoPersistentRingPresentation: Equatable {
    public init(
        mode: DuoPersistentRingMode,
        progress: Double,
        opacity: Double,
        batteryPresentation: BatteryRingPresentation
    ) {
        self.mode = mode
        self.progress = progress
        self.opacity = opacity
        self.batteryPresentation = batteryPresentation
    }

    public let mode: DuoPersistentRingMode
    public let progress: Double
    public let opacity: Double
    public let batteryPresentation: BatteryRingPresentation

    public static func battery(
        _ battery: BatteryStatus,
        colorCodingEnabled: Bool
    ) -> DuoPersistentRingPresentation {
        let progress: Double
        if battery.isFullyCharged {
            progress = 1
        } else if battery.isAvailable, let percentage = battery.percentage {
            progress = min(max(Double(percentage) / 100, 0), 1)
        } else {
            progress = 1
        }
        return DuoPersistentRingPresentation(
            mode: .battery,
            progress: progress,
            opacity: battery.isAvailable ? 1 : 0.22,
            batteryPresentation: BatteryRingPresentation.resolve(
                battery: battery,
                colorCodingEnabled: colorCodingEnabled
            )
        )
    }

    public static func adaptive(progress: Double) -> DuoPersistentRingPresentation {
        DuoPersistentRingPresentation(
            mode: .adaptive,
            progress: min(max(progress, 0), 1),
            opacity: 1,
            batteryPresentation: BatteryRingPresentation(
                boltPlacement: .none,
                colorRole: .monochrome
            )
        )
    }
}

public enum DuoPersistentRingPresentationResolver {
    public static func resolve(
        mode: DuoPersistentRingMode,
        battery: BatteryStatus,
        adaptiveProgress: Double,
        batteryColorCodingEnabled: Bool
    ) -> DuoPersistentRingPresentation {
        switch mode {
        case .battery:
            return .battery(battery, colorCodingEnabled: batteryColorCodingEnabled)
        case .adaptive:
            return .adaptive(progress: adaptiveProgress)
        }
    }
}

public struct DuoGlyphState: Equatable {
    public let ringPresentation: DuoPersistentRingPresentation
    public let batteryProgress: Double
    public let batteryArcOpacity: Double
    public let isCharging: Bool
    public let batteryPresentation: BatteryRingPresentation
    public let centerState: DuoCenterState
    public let volumeActiveDotCount: Int?
    public let feedback: DuoSemanticFeedback
    public let audioEventID: UUID?

    public init(
        status: SystemStatus,
        presentation: StatusPresentation = .normal,
        ringPresentation: DuoPersistentRingPresentation? = nil,
        centerStateOverride: DuoCenterState? = nil,
        batteryColorCodingEnabled: Bool = false
    ) {
        let battery = status.battery
        let resolvedRing = ringPresentation ?? .battery(
            battery,
            colorCodingEnabled: batteryColorCodingEnabled
        )
        self.ringPresentation = resolvedRing
        batteryProgress = resolvedRing.progress
        batteryArcOpacity = resolvedRing.opacity
        isCharging = resolvedRing.mode == .battery && battery.isAvailable && battery.isCharging
        batteryPresentation = resolvedRing.batteryPresentation
        volumeActiveDotCount = status.audio.volume.activeDotCount

        let normalCenter = centerStateOverride ?? Self.networkCenter(for: status.network)
        guard let event = presentation.event else {
            centerState = normalCenter
            feedback = .none
            audioEventID = nil
            return
        }

        switch event.kind {
        case .audioDeviceConnected(let device):
            switch device.temporaryConnectionGlyph {
            case .airPodsPro: centerState = .airPodsPro
            case .airPodsMax: centerState = .airPodsMax
            case .airPods: centerState = .airPods
            case .headphones: centerState = .headphones
            case .audioDevice: centerState = .audioDevice
            }
            feedback = .audioConnected
            audioEventID = event.id
        case .charging:
            centerState = normalCenter
            feedback = .charging
            audioEventID = nil
        case .lowBattery:
            centerState = normalCenter
            feedback = .lowBattery
            audioEventID = nil
        case .networkDisconnected:
            centerState = .offline
            feedback = .none
            audioEventID = nil
        }
    }

    private static func networkCenter(for network: NetworkStatus) -> DuoCenterState {
        guard network.isAvailable else { return .unavailable }
        guard network.isConnected else { return .offline }

        switch network.transport {
        case .wifi:
            return .wifi(network.wifiSignalLevel)
        case .ethernet:
            return .ethernet
        case .other:
            return .other
        case .none:
            return .offline
        }
    }
}
