import Foundation

enum WiFiNetworkSecurity: Equatable, Sendable {
    case open
    case personal
    case enterprise
}

struct ScannedWiFiNetwork: Equatable, Sendable {
    var ssid: String?
    var rssi: Int
    var security: WiFiNetworkSecurity
}

struct WiFiNetworkOption: Identifiable, Equatable, Sendable {
    var ssid: String
    var rssi: Int
    var security: WiFiNetworkSecurity
    var isCurrent: Bool
    var isKnown: Bool

    var id: String { ssid }

    var signalLevel: WiFiSignalLevel {
        WiFiSignalLevel(rssi: rssi)
    }
}

enum WiFiNetworkList {
    static func options(
        from scanned: [ScannedWiFiNetwork],
        currentSSID: String?,
        knownSSIDs: Set<String>
    ) -> [WiFiNetworkOption] {
        var strongestBySSID: [String: ScannedWiFiNetwork] = [:]
        for network in scanned {
            guard let ssid = SSIDValue.normalized(network.ssid) else { continue }
            if let existing = strongestBySSID[ssid], existing.rssi >= network.rssi { continue }
            strongestBySSID[ssid] = network
        }

        return strongestBySSID
            .map { ssid, network in
                WiFiNetworkOption(
                    ssid: ssid,
                    rssi: network.rssi,
                    security: network.security,
                    isCurrent: ssid == currentSSID,
                    isKnown: knownSSIDs.contains(ssid)
                )
            }
            .sorted { lhs, rhs in
                if lhs.isCurrent != rhs.isCurrent { return lhs.isCurrent }
                if lhs.rssi != rhs.rssi { return lhs.rssi > rhs.rssi }
                return lhs.ssid.localizedStandardCompare(rhs.ssid) == .orderedAscending
            }
    }
}

enum WiFiJoinAction: Equatable {
    case none
    case associate(password: String?)
    case requestPassword
    case openSystemSettings
    case showFailure

    static func initial(for option: WiFiNetworkOption) -> WiFiJoinAction {
        guard !option.isCurrent else { return .none }
        switch option.security {
        case .open:
            return .associate(password: nil)
        case .personal:
            return option.isKnown ? .associate(password: nil) : .requestPassword
        case .enterprise:
            return .openSystemSettings
        }
    }

    static func afterFailedAssociation(for option: WiFiNetworkOption, usedPassword: Bool) -> WiFiJoinAction {
        option.security == .personal && !usedPassword ? .requestPassword : .showFailure
    }
}
