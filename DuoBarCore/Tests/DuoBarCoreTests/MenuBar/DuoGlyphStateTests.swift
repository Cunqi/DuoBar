import XCTest
@testable import DuoBarCore

final class DuoGlyphStateTests: XCTestCase {
    func testBatteryRingRemainsDefaultWithoutPerformanceOverride() {
        let state = DuoGlyphState(status: makeStatus(batteryPercentage: 64, charging: true))
        XCTAssertEqual(state.batteryProgress, 0.64, accuracy: 0.001)
        XCTAssertTrue(state.isCharging)
    }

    func testPerformanceOverrideReusesRingAndSuppressesBatteryChargingState() {
        let state = DuoGlyphState(
            status: makeStatus(batteryPercentage: 64, charging: true),
            ringPresentation: .adaptive(progress: 0.82),
            centerStateOverride: .performanceThermal
        )
        XCTAssertEqual(state.batteryProgress, 0.82, accuracy: 0.001)
        XCTAssertFalse(state.isCharging)
        XCTAssertEqual(state.centerState, .performanceThermal)
    }

    func testNeutralAdaptiveRingUsesSingleProgressArcWithoutChangingVolumeOrNetwork() {
        let state = DuoGlyphState(
            status: makeStatus(batteryPercentage: 64, charging: true),
            ringPresentation: .adaptive(progress: 0.25)
        )
        XCTAssertEqual(state.batteryProgress, 0.25)
        XCTAssertEqual(state.batteryArcOpacity, 1)
        XCTAssertFalse(state.isCharging)
        XCTAssertEqual(state.centerState, .wifi(.strong))
        XCTAssertEqual(state.volumeActiveDotCount, 3)
    }

    func testPerformanceCenterOverrideDoesNotReplaceHigherPriorityStatusEvent() {
        let output = AudioDeviceStatus(
            uid: "test",
            name: "AirPods Pro",
            transport: .bluetooth,
            isAlive: true,
            modelUID: "2027 4c",
            manufacturer: "Apple Inc.",
            terminalType: .headphones
        )
        let event = StatusEvent(kind: .audioDeviceConnected(output), priority: .informational)
        let state = DuoGlyphState(
            status: makeStatus(),
            presentation: .event(event),
            ringPresentation: .adaptive(progress: 0.7),
            centerStateOverride: .performanceCPU
        )
        XCTAssertEqual(state.centerState, .airPodsPro)
    }

    func testBatteryLevelsMapLinearlyToArcProgress() {
        for percentage in [100, 75, 50, 25, 10, 0] {
            let state = DuoGlyphState(status: makeStatus(batteryPercentage: percentage))
            XCTAssertEqual(state.batteryProgress, Double(percentage) / 100, accuracy: 0.0001)
        }
    }

    func testNetworkTransportSelectsCorrectCenterState() {
        XCTAssertEqual(DuoGlyphState(status: makeStatus(network: wifi(rssi: -42))).centerState, .wifi(.strong))
        XCTAssertEqual(DuoGlyphState(status: makeStatus(network: wifi(rssi: -70))).centerState, .wifi(.medium))
        XCTAssertEqual(DuoGlyphState(status: makeStatus(network: wifi(rssi: -84))).centerState, .wifi(.weak))
        XCTAssertEqual(DuoGlyphState(status: makeStatus(network: ethernet())).centerState, .ethernet)
        XCTAssertEqual(DuoGlyphState(status: makeStatus(network: offline())).centerState, .offline)
        XCTAssertEqual(DuoGlyphState(status: makeStatus(network: otherNetwork())).centerState, .other)
    }

    func testVolumeLevelDrivesDotsAndBluetoothPowerDoesNot() {
        let on = DuoGlyphState(status: makeStatus(volume: 0.5, bluetoothPoweredOn: true))
        let off = DuoGlyphState(status: makeStatus(volume: 0.5, bluetoothPoweredOn: false))
        let muted = DuoGlyphState(status: makeStatus(volume: 0.9, muted: true))
        let unknown = DuoGlyphState(status: makeStatus(volume: nil))

        XCTAssertEqual(on.volumeActiveDotCount, 2)
        XCTAssertEqual(off.volumeActiveDotCount, 2)
        XCTAssertEqual(muted.volumeActiveDotCount, 0)
        XCTAssertNil(unknown.volumeActiveDotCount)
    }

    func testEveryVolumeBoundaryMapsToTheExistingFourPositions() {
        let cases: [(Double, Int)] = [
            (0, 0), (0.01, 1), (0.25, 1), (0.26, 2), (0.50, 2),
            (0.51, 3), (0.75, 3), (0.76, 4), (1.00, 4),
        ]
        for (volume, expected) in cases {
            XCTAssertEqual(makeStatus(volume: volume).audio.volume.activeDotCount, expected)
        }
        XCTAssertEqual(makeStatus(volume: 1, muted: true).audio.volume.activeDotCount, 0)
    }

    func testAudioConnectionTemporarilyOverridesNetworkCenter() {
        let device = AudioDeviceStatus(
            uid: "airpods",
            name: "AirPods Pro",
            transport: .bluetooth,
            isAlive: true,
            modelUID: "2027 4c",
            manufacturer: "Apple Inc.",
            terminalType: .headphones
        )
        let event = StatusEvent(kind: .audioDeviceConnected(device), priority: .informational, duration: 1.8)
        let state = DuoGlyphState(status: makeStatus(), presentation: .event(event))

        XCTAssertEqual(state.centerState, .airPodsPro)
        XCTAssertEqual(state.feedback, .audioConnected)
        XCTAssertEqual(state.audioEventID, event.id)
    }

    func testSemanticFeedbackIsTemporaryPresentationState() {
        let normal = DuoGlyphState(status: makeStatus(charging: true))
        let charging = DuoGlyphState(
            status: makeStatus(charging: true),
            presentation: .event(StatusEvent(kind: .charging, priority: .informational))
        )
        let low = DuoGlyphState(
            status: makeStatus(batteryPercentage: 8),
            presentation: .event(StatusEvent(kind: .lowBattery, priority: .critical))
        )

        XCTAssertEqual(normal.feedback, .none)
        XCTAssertEqual(charging.feedback, .charging)
        XCTAssertEqual(low.feedback, .lowBattery)
    }

    private func makeStatus(
        batteryPercentage: Int = 100,
        charging: Bool = false,
        network: NetworkStatus? = nil,
        volume: Double? = 0.75,
        muted: Bool = false,
        bluetoothPoweredOn: Bool = true
    ) -> SystemStatus {
        let device = AudioDeviceStatus(uid: "built-in", name: "MacBook Speakers", transport: .builtIn, isAlive: true)
        return SystemStatus(
            battery: BatteryStatus(
                percentage: batteryPercentage,
                isCharging: charging,
                isPluggedIn: charging,
                isFullyCharged: false,
                isAvailable: true
            ),
            network: network ?? wifi(rssi: -42),
            audio: AudioStatus(
                isAvailable: true,
                defaultOutput: device,
                volume: OutputVolumeStatus(level: volume, isMuted: muted, isSettable: volume != nil),
                connectedBluetoothOutputs: []
            ),
            bluetooth: BluetoothStatus(isAvailable: true, isPoweredOn: bluetoothPoweredOn)
        )
    }

    private func wifi(rssi: Int?) -> NetworkStatus {
        NetworkStatus(isAvailable: true, isConnected: true, transport: .wifi, interfaceName: "en0", isWiFiPoweredOn: true, ssid: "Test", rssi: rssi)
    }

    private func ethernet() -> NetworkStatus {
        NetworkStatus(isAvailable: true, isConnected: true, transport: .ethernet, interfaceName: "en1", isWiFiPoweredOn: true, ssid: nil, rssi: nil)
    }

    private func offline() -> NetworkStatus {
        NetworkStatus(isAvailable: true, isConnected: false, transport: .wifi, interfaceName: "en0", isWiFiPoweredOn: true, ssid: nil, rssi: nil)
    }

    private func otherNetwork() -> NetworkStatus {
        NetworkStatus(isAvailable: true, isConnected: true, transport: .other, interfaceName: "utun0", isWiFiPoweredOn: true, ssid: nil, rssi: nil)
    }
}
