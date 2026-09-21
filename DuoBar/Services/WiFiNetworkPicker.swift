import AppKit
@preconcurrency import CoreWLAN
import Foundation

@MainActor
final class WiFiNetworkPicker: ObservableObject {
    enum ScanState: Equatable {
        case idle
        case scanning
        case loaded
        case failed
    }

    @Published private(set) var scanState: ScanState = .idle
    @Published private(set) var options: [WiFiNetworkOption] = []
    @Published private(set) var joiningSSID: String?
    @Published private(set) var passwordPromptSSID: String?
    @Published private(set) var failedSSID: String?

    private let client = CWWiFiClient.shared()
    private let workQueue = DispatchQueue(label: "com.mikeli.duobar.wifi-picker", qos: .userInitiated)
    private var networksBySSID: [String: CWNetwork] = [:]
    private var scanGeneration = 0

    static let systemSettingsURL = URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension")!

    func scan(currentSSID: String?) {
        guard let interface = client.interface() else {
            scanState = .failed
            return
        }
        scanGeneration += 1
        let generation = scanGeneration
        if options.isEmpty {
            scanState = .scanning
        }

        workQueue.async { [weak self] in
            let scanned = try? interface.scanForNetworks(withSSID: nil)
            let known = Self.knownSSIDs(of: interface)
            DispatchQueue.main.async {
                guard let self, generation == self.scanGeneration else { return }
                guard let scanned else {
                    self.scanState = self.options.isEmpty ? .failed : .loaded
                    return
                }
                self.apply(scanned: scanned, known: known, currentSSID: currentSSID)
            }
        }
    }

    func updateCurrentSSID(_ currentSSID: String?) {
        options = WiFiNetworkList.options(
            from: options.map { ScannedWiFiNetwork(ssid: $0.ssid, rssi: $0.rssi, security: $0.security) },
            currentSSID: currentSSID,
            knownSSIDs: Set(options.filter(\.isKnown).map(\.ssid))
        )
    }

    func select(_ option: WiFiNetworkOption) {
        failedSSID = nil
        switch WiFiJoinAction.initial(for: option) {
        case .none:
            passwordPromptSSID = nil
        case let .associate(password):
            join(option, password: password)
        case .requestPassword:
            passwordPromptSSID = option.ssid
        case .openSystemSettings:
            openSystemSettings()
        case .showFailure:
            failedSSID = option.ssid
        }
    }

    func submitPassword(_ password: String, for option: WiFiNetworkOption) {
        failedSSID = nil
        join(option, password: password)
    }

    func cancelPasswordPrompt() {
        passwordPromptSSID = nil
    }

    func openSystemSettings() {
        NSWorkspace.shared.open(Self.systemSettingsURL)
    }

    private func join(_ option: WiFiNetworkOption, password: String?) {
        guard let interface = client.interface(), let network = networksBySSID[option.ssid] else {
            failedSSID = option.ssid
            return
        }
        joiningSSID = option.ssid

        workQueue.async { [weak self] in
            let succeeded: Bool
            do {
                try interface.associate(to: network, password: password)
                succeeded = true
            } catch {
                succeeded = false
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.joiningSSID = nil
                if succeeded {
                    self.passwordPromptSSID = nil
                    self.updateCurrentSSID(option.ssid)
                    return
                }
                switch WiFiJoinAction.afterFailedAssociation(for: option, usedPassword: password != nil) {
                case .requestPassword:
                    self.passwordPromptSSID = option.ssid
                default:
                    self.failedSSID = option.ssid
                }
            }
        }
    }

    private func apply(scanned: Set<CWNetwork>, known: Set<String>, currentSSID: String?) {
        var networks: [String: CWNetwork] = [:]
        var entries: [ScannedWiFiNetwork] = []
        for network in scanned {
            guard let ssid = SSIDValue.normalized(network.ssid) else { continue }
            if let existing = networks[ssid], existing.rssiValue >= network.rssiValue {
                continue
            }
            networks[ssid] = network
        }
        for (ssid, network) in networks {
            entries.append(ScannedWiFiNetwork(ssid: ssid, rssi: network.rssiValue, security: Self.security(of: network)))
        }
        networksBySSID = networks
        options = WiFiNetworkList.options(from: entries, currentSSID: currentSSID, knownSSIDs: known)
        scanState = .loaded
    }

    nonisolated private static func knownSSIDs(of interface: CWInterface) -> Set<String> {
        guard let profiles = interface.configuration()?.networkProfiles.array as? [CWNetworkProfile] else { return [] }
        return Set(profiles.compactMap { SSIDValue.normalized($0.ssid) })
    }

    nonisolated private static func security(of network: CWNetwork) -> WiFiNetworkSecurity {
        let openModes: [CWSecurity] = [.none, .OWE, .oweTransition]
        if openModes.contains(where: network.supportsSecurity) {
            return .open
        }
        let enterpriseModes: [CWSecurity] = [.dynamicWEP, .wpaEnterprise, .wpaEnterpriseMixed, .wpa2Enterprise, .enterprise, .wpa3Enterprise]
        let personalModes: [CWSecurity] = [.WEP, .wpaPersonal, .wpaPersonalMixed, .wpa2Personal, .personal, .wpa3Personal, .wpa3Transition]
        if enterpriseModes.contains(where: network.supportsSecurity), !personalModes.contains(where: network.supportsSecurity) {
            return .enterprise
        }
        return .personal
    }
}
