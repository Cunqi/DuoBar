import Foundation
import DuoBarCore

extension RingContent {
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

    static func stored(in defaults: UserDefaults = .standard) -> RingContent {
        defaults.string(forKey: PreferenceKeys.ringContent).flatMap(RingContent.init(rawValue:)) ?? defaultValue
    }
}

extension RingReading {
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
