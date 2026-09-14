import Foundation

enum DuoCenterState: Hashable {
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
}

enum DuoSemanticFeedback: Equatable {
    case none
    case charging
    case lowBattery
    case audioConnected
}

struct DuoGlyphState: Equatable {
    let batteryProgress: Double
    let batteryArcOpacity: Double
    let isCharging: Bool
    let centerState: DuoCenterState
    let volumeActiveDotCount: Int?
    let feedback: DuoSemanticFeedback
    let audioEventID: UUID?

    init(status: SystemStatus, presentation: StatusPresentation = .normal) {
        let battery = status.battery
        if battery.isFullyCharged {
            batteryProgress = 1
        } else if battery.isAvailable, let percentage = battery.percentage {
            batteryProgress = min(max(Double(percentage) / 100, 0), 1)
        } else {
            batteryProgress = 1
        }
        batteryArcOpacity = battery.isAvailable ? 1 : 0.22
        isCharging = battery.isAvailable && battery.isCharging
        volumeActiveDotCount = status.audio.volume.activeDotCount

        let normalCenter = Self.networkCenter(for: status.network)
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
