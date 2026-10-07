import DuoBarCore
import Foundation

enum MenuBarAccessibilitySummary {
    static func text(ring: RingReading, status: SystemStatus) -> String {
        let network: String
        switch status.network.transport {
        case .ethernet:
            network = status.network.isConnected ? localized("Ethernet connected") : localized("Ethernet disconnected")
        case .wifi:
            network = status.network.isConnected ? localized("Wi-Fi connected") : localized("Wi-Fi disconnected")
        case .other, .none:
            network = status.network.isConnected ? localized("Network connected") : localized("Network disconnected")
        }
        let volume: String
        if status.audio.volume.isMuted {
            volume = localized("volume muted")
        } else {
            volume = status.audio.volume.percentage.map { localized("volume %d percent", $0) } ?? localized("volume unavailable")
        }
        return localized("%@, %@, %@", network, volume, ring.localizedDescription)
    }
}
