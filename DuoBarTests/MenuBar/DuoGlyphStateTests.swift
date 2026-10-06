import DuoBarCore
@testable import DuoBarKit
import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class DuoGlyphStateTests: XCTestCase {





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


    func testNativeWiFiBandsKeepTheCompleteStructureVisible() {
        XCTAssertEqual(DuoWiFiVisualStyle.opacity(for: .core, level: .strong), 1)
        XCTAssertEqual(DuoWiFiVisualStyle.opacity(for: .middle, level: .strong), 1)
        XCTAssertEqual(DuoWiFiVisualStyle.opacity(for: .outer, level: .strong), 1)

        XCTAssertEqual(DuoWiFiVisualStyle.opacity(for: .core, level: .medium), 1)
        XCTAssertEqual(DuoWiFiVisualStyle.opacity(for: .middle, level: .medium), 1)
        XCTAssertEqual(
            DuoWiFiVisualStyle.opacity(for: .outer, level: .medium),
            DuoNativeVisualConstants.inactiveElementOpacity
        )

        XCTAssertEqual(DuoWiFiVisualStyle.opacity(for: .core, level: .weak), 1)
        XCTAssertEqual(
            DuoWiFiVisualStyle.opacity(for: .middle, level: .weak),
            DuoNativeVisualConstants.inactiveElementOpacity
        )
        XCTAssertEqual(
            DuoWiFiVisualStyle.opacity(for: .outer, level: .weak),
            DuoNativeVisualConstants.inactiveElementOpacity
        )
    }

    func testUnavailableWiFiKeepsAllBandsStructurallyPresent() {
        for band in DuoWiFiVisualStyle.Band.allCases {
            XCTAssertEqual(
                DuoWiFiVisualStyle.opacity(for: band, level: .unavailable),
                DuoNativeVisualConstants.inactiveElementOpacity
            )
        }
    }

    func testWiFiGeometryMatchesMeasuredReferenceProportions() {
        XCTAssertEqual(DuoWiFiReferenceGeometry.totalWidthRatio, 100.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoWiFiReferenceGeometry.totalHeightRatio, 73.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoWiFiReferenceGeometry.outerArcWidthRatio, 100.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoWiFiReferenceGeometry.outerArcHeightRatio, 31.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoWiFiReferenceGeometry.innerArcWidthRatio, 64.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoWiFiReferenceGeometry.innerArcHeightRatio, 23.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoWiFiReferenceGeometry.strokeWidthRatio, 14.5 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoWiFiReferenceGeometry.coreWidthRatio, 29.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoWiFiReferenceGeometry.coreHeightRatio, 21.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoWiFiReferenceGeometry.outerToInnerCenterGapRatio, 11.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoWiFiReferenceGeometry.innerToCoreCenterGapRatio, 12.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoWiFiReferenceGeometry.opticalCenterYOffsetRatio, -15.0 / 230.0, accuracy: 0.0001)
    }

    func testWiFiOpticalAdjustmentKeepsMeasuredCenterAtEverySupportedScale() {
        for scale in [0.80, 1.00, 1.05] {
            let metrics = DuoGlyphMetrics.standard.scaled(by: scale)
            let adjustment = DuoWiFiReferenceGeometry.verticalAdjustment(
                ringDiameter: metrics.ringDiameter,
                ringYOffset: metrics.ringYOffset,
                centerYOffset: metrics.wifiYOffset
            )
            let resolvedCenter = metrics.wifiYOffset + adjustment
            let expectedCenter = metrics.ringYOffset
                + metrics.ringDiameter * DuoWiFiReferenceGeometry.opticalCenterYOffsetRatio
            XCTAssertEqual(resolvedCenter, expectedCenter, accuracy: 0.0001)
        }
    }



    func testInactiveAndUnknownVolumeDotsRemainVisible() {
        let metrics = DuoGlyphMetrics.standard
        let muted = DuoDotRow(
            activeCount: 0,
            diameter: metrics.dotDiameter,
            ringDiameter: metrics.ringDiameter,
            rowCenterYOffset: metrics.dotYOffset,
            animationsEnabled: false
        )
        let partial = DuoDotRow(
            activeCount: 2,
            diameter: metrics.dotDiameter,
            ringDiameter: metrics.ringDiameter,
            rowCenterYOffset: metrics.dotYOffset,
            animationsEnabled: false
        )
        let unknown = DuoDotRow(
            activeCount: nil,
            diameter: metrics.dotDiameter,
            ringDiameter: metrics.ringDiameter,
            rowCenterYOffset: metrics.dotYOffset,
            animationsEnabled: false
        )

        for index in 0..<4 {
            XCTAssertEqual(muted.opacity(for: index), DuoVolumeIndicatorGeometry.inactiveOpacity)
            XCTAssertEqual(unknown.opacity(for: index), DuoVolumeIndicatorGeometry.unknownOpacity)
        }
        XCTAssertEqual(partial.opacity(for: 0), DuoVolumeIndicatorGeometry.activeOpacity)
        XCTAssertEqual(partial.opacity(for: 1), DuoVolumeIndicatorGeometry.activeOpacity)
        XCTAssertEqual(partial.opacity(for: 2), DuoVolumeIndicatorGeometry.inactiveOpacity)
        XCTAssertEqual(partial.opacity(for: 3), DuoVolumeIndicatorGeometry.inactiveOpacity)
    }

    func testVolumeGeometryMatchesMeasuredReferenceProportions() {
        XCTAssertEqual(DuoVolumeIndicatorGeometry.indicatorDiameterRatio, 21.5 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoVolumeIndicatorGeometry.rowWidthRatio, 132.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoVolumeIndicatorGeometry.rowHeightRatio, 35.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoVolumeIndicatorGeometry.outerEdgeGapRatio, 14.25 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoVolumeIndicatorGeometry.innerEdgeGapRatio, 17.5 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoVolumeIndicatorGeometry.wifiToRowGapRatio, 33.25 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoVolumeIndicatorGeometry.rowToRingBottomGapRatio, 25.75 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(DuoVolumeIndicatorGeometry.centerXOffsets, [-55.25 / 230.0, -19.5 / 230.0, 19.5 / 230.0, 55.25 / 230.0])
        XCTAssertEqual(DuoVolumeIndicatorGeometry.centerYOffsets, [-6.5 / 230.0, 6.5 / 230.0, 6.5 / 230.0, -6.5 / 230.0])
        XCTAssertEqual(DuoVolumeIndicatorGeometry.activeOpacity, 1)
        XCTAssertEqual(DuoVolumeIndicatorGeometry.inactiveOpacity, 0.30)
        XCTAssertEqual(DuoVolumeIndicatorGeometry.unknownOpacity, 0.30)
    }

    func testNativeVisualMetricsScaleProportionallyAtEverySupportedEndpoint() {
        let standard = DuoGlyphMetrics.standard
        for scale in [0.80, 1.00, 1.05] {
            let metrics = standard.scaled(by: scale)
            XCTAssertEqual(metrics.ringDiameter / standard.ringDiameter, scale, accuracy: 0.0001)
            XCTAssertEqual(metrics.ringLineWidth / standard.ringLineWidth, scale, accuracy: 0.0001)
            XCTAssertEqual(metrics.wifiSymbolSize / standard.wifiSymbolSize, scale, accuracy: 0.0001)
            XCTAssertEqual(metrics.dotDiameter / standard.dotDiameter, scale, accuracy: 0.0001)
            XCTAssertEqual(metrics.dotSpacing / standard.dotSpacing, scale, accuracy: 0.0001)
        }
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
