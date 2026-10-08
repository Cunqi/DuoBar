import DuoBarCore
import Testing
@testable import DuoBar

struct MenuBarAccessibilityRegressionTests {
    @Test("菜单栏无障碍摘要描述当前外圈读数", arguments: [
        RingReading.battery(percent: 79),
        .brightness(percent: 60),
        .cpu(percent: 42),
        .memory(percent: 63),
        .thermal(.serious),
        .volume(percent: 25),
        .unavailable
    ])
    func summaryDescribesActualRingReading(_ ring: RingReading) {
        let status = makeStatus()
        let summary = MenuBarAccessibilitySummary.text(ring: ring, status: status)

        #expect(summary == localized(
            "%@, %@, %@",
            localized("Wi-Fi connected"),
            localized("volume %d percent", 75),
            ring.localizedDescription
        ))
    }

    @Test("桌面亮度外圈不朗读不存在的电池")
    func desktopBrightnessDoesNotAnnounceMissingBattery() {
        var status = makeStatus()
        status.battery = .unavailable
        let ring = RingReading.brightness(percent: 60)
        let summary = MenuBarAccessibilitySummary.text(ring: ring, status: status)

        #expect(summary.contains(ring.localizedDescription))
        #expect(!summary.contains(localized("battery unavailable")))
    }

    @Test("外圈摘要保留网络和静音状态的本地化")
    func summaryPreservesNetworkAndVolumeLocalization() {
        var status = makeStatus()
        status.network.transport = .ethernet
        status.audio.volume.isMuted = true
        let ring = RingReading.cpu(percent: 42)
        let summary = MenuBarAccessibilitySummary.text(ring: ring, status: status)

        #expect(summary.contains(localized("Ethernet connected")))
        #expect(summary.contains(localized("volume muted")))

        status.network.isConnected = false
        status.audio.volume = .unavailable
        let unavailableSummary = MenuBarAccessibilitySummary.text(ring: .unavailable, status: status)

        #expect(unavailableSummary.contains(localized("Ethernet disconnected")))
        #expect(unavailableSummary.contains(localized("volume unavailable")))
    }

    private func makeStatus() -> SystemStatus {
        SystemStatus(
            battery: BatteryStatus(
                percentage: 79,
                isCharging: false,
                isPluggedIn: false,
                isFullyCharged: false,
                isAvailable: true
            ),
            network: NetworkStatus(
                isAvailable: true,
                isConnected: true,
                transport: .wifi,
                interfaceName: "en0",
                isWiFiPoweredOn: true,
                ssid: "Home",
                rssi: -42
            ),
            audio: AudioStatus(
                isAvailable: true,
                defaultOutput: nil,
                volume: OutputVolumeStatus(level: 0.75, isMuted: false, isSettable: true),
                connectedBluetoothOutputs: []
            ),
            bluetooth: .unavailable
        )
    }
}
