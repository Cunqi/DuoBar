@preconcurrency import CoreLocation
@preconcurrency import CoreWLAN
import Foundation
@preconcurrency import Network

@MainActor
final class NetworkService: NSObject, @preconcurrency CLLocationManagerDelegate {
    var onStatusChange: ((NetworkStatus) -> Void)?

    private let client = CWWiFiClient.shared()
    private let locationManager = CLLocationManager()
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mikeli.duobar.network-monitor", qos: .utility)
    private var latestPath: NWPath?
    private var detailRefreshTimer: Timer?
    private var lastStatus: NetworkStatus?
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true
        locationManager.delegate = self

        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.latestPath = path
                self?.refresh()
            }
        }
        pathMonitor.start(queue: monitorQueue)

        // NWPathMonitor supplies immediate connection and interface changes. This
        // low-frequency refresh is only for CoreWLAN details such as changing RSSI.
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        detailRefreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)

        refresh()
    }

    func requestSSIDAccess() {
        guard locationManager.authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    func refresh() {
        let path = latestPath ?? pathMonitor.currentPath
        let wifiInterface = client.interface()
        let isConnected = path.status == .satisfied
        let activeInterface = preferredInterface(in: path)
        let transport = resolvedTransport(
            pathIsConnected: isConnected,
            activeInterface: activeInterface,
            hasWiFiInterface: wifiInterface != nil
        )
        let wifiPoweredOn = wifiInterface?.powerOn()

        var ssid: String?
        var rssi: Int?
        if transport == .wifi, let wifiInterface {
            let rawSSID = wifiInterface.ssid()?.trimmingCharacters(in: .whitespacesAndNewlines)
            ssid = rawSSID?.isEmpty == false ? rawSSID : nil
            let rawRSSI = wifiInterface.rssiValue()
            rssi = rawRSSI == 0 ? nil : rawRSSI
        }

        publish(
            NetworkStatus(
                isAvailable: wifiInterface != nil || !path.availableInterfaces.isEmpty,
                isConnected: isConnected,
                transport: transport,
                interfaceName: activeInterface?.name,
                isWiFiPoweredOn: wifiPoweredOn,
                ssid: ssid,
                rssi: rssi
            )
        )
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refresh()
    }

    private func preferredInterface(in path: NWPath) -> NWInterface? {
        // Prefer a routed wired path when both Wi-Fi and Ethernet are available.
        // The fallback preserves NWPath's own interface order for other transports.
        path.availableInterfaces.first {
            $0.type == .wiredEthernet && path.usesInterfaceType(.wiredEthernet)
        } ?? path.availableInterfaces.first {
            $0.type == .wifi && path.usesInterfaceType(.wifi)
        } ?? path.availableInterfaces.first { path.usesInterfaceType($0.type) }
    }

    private func resolvedTransport(
        pathIsConnected: Bool,
        activeInterface: NWInterface?,
        hasWiFiInterface: Bool
    ) -> NetworkTransport {
        guard pathIsConnected else { return hasWiFiInterface ? .wifi : .none }
        switch activeInterface?.type {
        case .wifi: return .wifi
        case .wiredEthernet: return .ethernet
        case .some: return .other
        case .none: return .none
        }
    }

    private func publish(_ status: NetworkStatus) {
        guard status != lastStatus else { return }
        lastStatus = status
        onStatusChange?(status)
    }

    deinit {
        detailRefreshTimer?.invalidate()
        pathMonitor.cancel()
    }
}
