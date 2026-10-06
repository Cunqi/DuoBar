import Foundation

public enum WiFiNetworkSecurity: Equatable, Sendable {
    case open
    case personal
    case enterprise
}

public struct ScannedWiFiNetwork: Equatable, Sendable {
    public init(
        ssid: String?,
        rssi: Int,
        security: WiFiNetworkSecurity
    ) {
        self.ssid = ssid
        self.rssi = rssi
        self.security = security
    }

    public var ssid: String?
    public var rssi: Int
    public var security: WiFiNetworkSecurity
}

public struct WiFiNetworkOption: Identifiable, Equatable, Sendable {
    public init(
        ssid: String,
        rssi: Int,
        security: WiFiNetworkSecurity,
        isCurrent: Bool,
        isKnown: Bool
    ) {
        self.ssid = ssid
        self.rssi = rssi
        self.security = security
        self.isCurrent = isCurrent
        self.isKnown = isKnown
    }

    public var ssid: String
    public var rssi: Int
    public var security: WiFiNetworkSecurity
    public var isCurrent: Bool
    public var isKnown: Bool

    public var id: String { ssid }

    public var signalLevel: WiFiSignalLevel {
        WiFiSignalLevel(rssi: rssi)
    }
}

public enum WiFiNetworkList {
    public static func options(
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

public enum WiFiJoinAction: Equatable {
    case none
    case associate(password: String?)
    case requestPassword
    case openSystemSettings
    case showFailure

    public static func initial(for option: WiFiNetworkOption) -> WiFiJoinAction {
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

    public static func afterFailedAssociation(for option: WiFiNetworkOption, usedPassword: Bool) -> WiFiJoinAction {
        option.security == .personal && !usedPassword ? .requestPassword : .showFailure
    }
}
