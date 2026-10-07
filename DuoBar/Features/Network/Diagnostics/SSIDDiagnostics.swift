import Foundation
import Combine
import DuoBarCore

#if DEBUG
struct SSIDHardwareDiagnostic: Equatable, Sendable {
    var authorization: SSIDAuthorizationState
    var applicationIsActive: Bool
    var interfaceName: String?
    var isWiFiPoweredOn: Bool?
    var rawSSID: String?
    var networkStatusSSID: String?
    var pathDescription: String
    var rssi: Int?
    var refreshReason: NetworkRefreshReason
    var locationRequestAttempted: Bool
    var locationRequestIssuedWhileActive: Bool
    var lastLocationRequestTrigger: LocationRequestTrigger

    var copyableReport: String {
        [
            "Location authorization: \(authorization.diagnosticLabel)",
            "Application active: \(applicationIsActive ? "Yes" : "No")",
            "Wi-Fi interface: \(interfaceName ?? "unavailable")",
            "Wi-Fi power: \(isWiFiPoweredOn.map { $0 ? "On" : "Off" } ?? "Unavailable")",
            "CoreWLAN SSID raw result: \(rawSSID ?? "nil")",
            "NetworkStatus SSID: \(networkStatusSSID ?? "nil")",
            "NWPath: \(pathDescription)",
            "RSSI: \(rssi.map(String.init) ?? "unavailable")",
            "Last SSID refresh reason: \(refreshReason.diagnosticLabel)",
            "Location request attempted: \(locationRequestAttempted ? "Yes" : "No")",
            "Location request issued while active: \(locationRequestIssuedWhileActive ? "Yes" : "No")",
            "Last location request trigger: \(lastLocationRequestTrigger.diagnosticLabel)"
        ].joined(separator: "\n")
    }
}

extension Notification.Name {
    static let debugSSIDManualRefresh = Notification.Name("com.mikeli.duobar.debug-ssid-manual-refresh")
}

@MainActor
final class SSIDDiagnosticCenter: ObservableObject {
    static let shared = SSIDDiagnosticCenter()

    @Published private(set) var diagnostic: SSIDHardwareDiagnostic?

    private init() {}

    func update(_ diagnostic: SSIDHardwareDiagnostic) {
        self.diagnostic = diagnostic
    }

    func requestRefresh() {
        NotificationCenter.default.post(name: .debugSSIDManualRefresh, object: nil)
    }
}
#endif
