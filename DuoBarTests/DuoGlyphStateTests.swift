import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class DuoGlyphStateTests: XCTestCase {
    func testBatteryRingRemainsDefaultWithoutPerformanceOverride() {
        let state = DuoGlyphState(status: makeStatus(batteryPercentage: 64, charging: true))
        XCTAssertEqual(state.batteryProgress, 0.64, accuracy: 0.001)
        XCTAssertTrue(state.isCharging)
    }

    func testPerformanceOverrideReusesRingAndSuppressesBatteryChargingState() {
        let state = DuoGlyphState(
            status: makeStatus(batteryPercentage: 64, charging: true),
            ringProgressOverride: 0.82,
            centerStateOverride: .performanceThermal
        )
        XCTAssertEqual(state.batteryProgress, 0.82, accuracy: 0.001)
        XCTAssertFalse(state.isCharging)
        XCTAssertEqual(state.centerState, .performanceThermal)
    }

    func testNeutralAdaptiveRingUsesSingleProgressArcWithoutChangingVolumeOrNetwork() {
        let state = DuoGlyphState(
            status: makeStatus(batteryPercentage: 64, charging: true),
            ringProgressOverride: 0.25
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
            ringProgressOverride: 0.7,
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

    func testArcKeepsLeftAnchorAndMovesOnlyItsRightEndpoint() {
        let metrics = DuoGlyphMetrics.standard
        let full = DuoArcShape(startDegrees: metrics.arcStartDegrees, endDegrees: metrics.arcEndDegrees, progress: 1)
        let half = DuoArcShape(startDegrees: metrics.arcStartDegrees, endDegrees: metrics.arcEndDegrees, progress: 0.5)
        let empty = DuoArcShape(startDegrees: metrics.arcStartDegrees, endDegrees: metrics.arcEndDegrees, progress: 0)

        XCTAssertEqual(full.startDegrees, half.startDegrees)
        XCTAssertEqual(half.startDegrees, empty.startDegrees)
        XCTAssertEqual(full.visibleEndDegrees, metrics.arcEndDegrees, accuracy: 0.0001)
        XCTAssertEqual(half.visibleEndDegrees, metrics.arcStartDegrees + (metrics.arcEndDegrees - metrics.arcStartDegrees) / 2, accuracy: 0.0001)
        XCTAssertEqual(empty.visibleEndDegrees, metrics.arcStartDegrees, accuracy: 0.0001)
    }

    func testNetworkTransportSelectsCorrectCenterState() {
        XCTAssertEqual(DuoGlyphState(status: makeStatus(network: wifi(rssi: -42))).centerState, .wifi(.strong))
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

    @MainActor
    func testRenderAcceptanceStateGallery() throws {
        let airPods = AudioDeviceStatus(
            uid: "airpods",
            name: "AirPods Pro",
            transport: .bluetooth,
            isAlive: true,
            modelUID: "2027 4c",
            manufacturer: "Apple Inc.",
            terminalType: .headphones
        )
        let scenarios = [
            PreviewScenario(name: "Wi-Fi · 4", status: makeStatus(batteryPercentage: 100, volume: 1)),
            PreviewScenario(name: "Wi-Fi · 2", status: makeStatus(batteryPercentage: 50, volume: 0.5)),
            PreviewScenario(name: "Weak · 1", status: makeStatus(batteryPercentage: 25, network: wifi(rssi: -84), volume: 0.1)),
            PreviewScenario(name: "Ethernet", status: makeStatus(network: ethernet(), volume: 0.76)),
            PreviewScenario(name: "Offline · mute", status: makeStatus(network: offline(), volume: 0.5, muted: true)),
            PreviewScenario(name: "Unknown volume", status: makeStatus(volume: nil)),
            PreviewScenario(
                name: "Charging event",
                status: makeStatus(batteryPercentage: 60, charging: true),
                presentation: .event(StatusEvent(kind: .charging, priority: .informational))
            ),
            PreviewScenario(
                name: "AirPods event",
                status: makeStatus(),
                presentation: .event(StatusEvent(kind: .audioDeviceConnected(airPods), priority: .informational))
            )
        ]

        let gallery = HStack(alignment: .top, spacing: 18) {
            ForEach(scenarios) { scenario in
                VStack(spacing: 8) {
                    DuoGlyphView(
                        status: scenario.status,
                        presentation: scenario.presentation,
                        metrics: DuoGlyphMetrics.standard.sized(88),
                        animationsEnabled: false
                    )
                    Text(scenario.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 112)
            }
        }
        .padding(20)
        .background(Color.black)
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: gallery)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage)
        let representation = try XCTUnwrap(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("DuoBar-1.0-StateGallery.png")
        try png.write(to: outputURL, options: .atomic)
        XCTAssertGreaterThan(png.count, 1_000)
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

private struct PreviewScenario: Identifiable {
    let name: String
    let status: SystemStatus
    var presentation: StatusPresentation = .normal
    var id: String { name }
}
