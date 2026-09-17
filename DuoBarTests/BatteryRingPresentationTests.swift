import XCTest
@testable import DuoBar

final class BatteryRingPresentationTests: XCTestCase {
    func testColorCodingDefaultsToMonochrome() {
        XCTAssertEqual(presentation(percentage: 10, colorCoding: false).colorRole, .monochrome)
        XCTAssertEqual(presentation(percentage: 10, charging: true, colorCoding: false).colorRole, .monochrome)
    }

    func testMissingOrCorruptedColorCodingPreferenceIsSafelyOff() {
        let suiteName = "BatteryRingPresentationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertFalse(defaults.bool(forKey: PreferenceKeys.batteryColorCoding))
        defaults.set("not-a-boolean", forKey: PreferenceKeys.batteryColorCoding)
        XCTAssertFalse(defaults.bool(forKey: PreferenceKeys.batteryColorCoding))
    }

    func testChargingTakesColorPriority() {
        XCTAssertEqual(presentation(percentage: 15, charging: true, lowPowerMode: true).colorRole, .charging)
    }

    func testFullPluggedOverridesChargingColor() {
        XCTAssertEqual(
            presentation(percentage: 100, charging: true, pluggedIn: true, fullyCharged: true).colorRole,
            .monochrome
        )
    }

    func testLowPowerModeIsYellowSemanticRoleAtAnyLevel() {
        XCTAssertEqual(presentation(percentage: 10, lowPowerMode: true).colorRole, .lowPowerMode)
        XCTAssertEqual(presentation(percentage: 50, lowPowerMode: true).colorRole, .lowPowerMode)
    }

    func testLowBatteryIsStrictlyBelowTwentyPercent() {
        XCTAssertEqual(presentation(percentage: 19).colorRole, .lowBattery)
        XCTAssertEqual(presentation(percentage: 20).colorRole, .monochrome)
    }

    func testNormalBatteryRemainsMonochromeWithColorCoding() {
        XCTAssertEqual(presentation(percentage: 50).colorRole, .monochrome)
    }

    func testChargingBelowFullUsesRingEndpointBolt() {
        XCTAssertEqual(presentation(percentage: 20, charging: true).boltPlacement, .ringEndpoint)
    }

    func testUnpluggedBatteryHasNoBolt() {
        XCTAssertEqual(presentation(percentage: 80).boltPlacement, .none)
    }

    func testPluggedButNotFullDoesNotUseMidpointPresentation() {
        XCTAssertEqual(presentation(percentage: 99, pluggedIn: true).boltPlacement, .none)
    }

    func testFullConnectedBatteryUsesVisibleRingMidpointBolt() {
        XCTAssertEqual(
            presentation(percentage: 100, pluggedIn: true, fullyCharged: true).boltPlacement,
            .ringMidpoint
        )
    }

    func testRingMidpointDerivesFromSharedRingGeometry() {
        let metrics = DuoGlyphMetrics.standard
        XCTAssertEqual(
            DuoRingGeometry.midpoint(metrics: metrics),
            DuoRingGeometry.endpoint(metrics: metrics, progress: 0.5)
        )
    }

    func testRingEndpointUsesTheSameAngleAsTheArc() {
        let metrics = DuoGlyphMetrics.standard
        for percentage in [20, 50, 80, 99] {
            let progress = Double(percentage) / 100
            let arc = DuoArcShape(
                startDegrees: metrics.arcStartDegrees,
                endDegrees: metrics.arcEndDegrees,
                progress: progress
            )
            let endpoint = DuoRingGeometry.endpoint(metrics: metrics, progress: progress)
            let endpointAngle = atan2(endpoint.y - metrics.ringYOffset, endpoint.x) * 180 / .pi
            XCTAssertEqual(normalizedDegrees(endpointAngle), normalizedDegrees(arc.visibleEndDegrees), accuracy: 0.0001)
        }
    }

    func testEndpointGeometryScalesWithGlyphMetrics() {
        for scale in [0.80, 1.00, 1.05] {
            let metrics = DuoGlyphMetrics.standard.scaled(by: scale)
            let endpoint = DuoRingGeometry.endpoint(metrics: metrics, progress: 0.5)
            let expectedRadius = metrics.ringDiameter / 2
            let actualRadius = hypot(endpoint.x, endpoint.y - metrics.ringYOffset)
            XCTAssertEqual(actualRadius, expectedRadius, accuracy: 0.0001)
            XCTAssertEqual(DuoGlyphMetrics.menuBarVerticalOffset, 1, accuracy: 0.0001)
        }
    }

    func testChargingBelowFullPreservesNetworkCenter() {
        let state = DuoGlyphState(status: status(percentage: 50, charging: true, pluggedIn: true))
        XCTAssertEqual(state.centerState, .wifi(.strong))
        XCTAssertEqual(state.batteryPresentation.boltPlacement, .ringEndpoint)
    }

    func testFullConnectedUsesRingMidpointBoltWithoutReplacingNetwork() {
        let state = DuoGlyphState(status: status(percentage: 100, pluggedIn: true, fullyCharged: true))
        XCTAssertEqual(state.centerState, .wifi(.strong))
        XCTAssertEqual(state.batteryPresentation.boltPlacement, .ringMidpoint)
    }

    func testUnpluggingFullBatteryRestoresNormalNetworkCenter() {
        let state = DuoGlyphState(status: status(percentage: 100, fullyCharged: true))
        XCTAssertEqual(state.centerState, .wifi(.strong))
        XCTAssertEqual(state.batteryPresentation.boltPlacement, .none)
    }

    func testAudioEventRetainsPriorityOverFullChargeCenterBolt() {
        let device = AudioDeviceStatus(
            uid: "airpods", name: "AirPods Pro", transport: .bluetooth, isAlive: true,
            modelUID: "2027 4c", manufacturer: "Apple Inc.", terminalType: .headphones
        )
        let event = StatusEvent(kind: .audioDeviceConnected(device), priority: .informational)
        let state = DuoGlyphState(
            status: status(percentage: 100, pluggedIn: true, fullyCharged: true),
            presentation: .event(event)
        )
        XCTAssertEqual(state.centerState, .airPodsPro)
        XCTAssertEqual(state.batteryPresentation.boltPlacement, .ringMidpoint)
    }

    func testAdaptiveRingOverrideCannotLeakBatteryBolt() {
        let state = DuoGlyphState(
            status: status(percentage: 50, charging: true, pluggedIn: true),
            ringProgressOverride: 0.72
        )
        XCTAssertEqual(state.batteryPresentation.boltPlacement, .none)
    }

    func testFinalBoltPresentationConstants() {
        XCTAssertEqual(BatteryBoltPresentationConstants.sizeScale, 1.45, accuracy: 0.0001)
        XCTAssertEqual(BatteryBoltPresentationConstants.opacity, 0.85, accuracy: 0.0001)
        XCTAssertEqual(BatteryBoltPresentationConstants.radialOffset, -0.5, accuracy: 0.0001)
    }

    private func presentation(
        percentage: Int,
        charging: Bool = false,
        pluggedIn: Bool = false,
        fullyCharged: Bool = false,
        lowPowerMode: Bool = false,
        colorCoding: Bool = true
    ) -> BatteryRingPresentation {
        BatteryRingPresentation.resolve(
            battery: BatteryStatus(
                percentage: percentage,
                isCharging: charging,
                isPluggedIn: pluggedIn,
                isFullyCharged: fullyCharged,
                isAvailable: true,
                isLowPowerModeEnabled: lowPowerMode
            ),
            colorCodingEnabled: colorCoding
        )
    }

    private func status(
        percentage: Int,
        charging: Bool = false,
        pluggedIn: Bool = false,
        fullyCharged: Bool = false
    ) -> SystemStatus {
        SystemStatus(
            battery: BatteryStatus(
                percentage: percentage,
                isCharging: charging,
                isPluggedIn: pluggedIn,
                isFullyCharged: fullyCharged,
                isAvailable: true
            ),
            network: NetworkStatus(
                isAvailable: true, isConnected: true, transport: .wifi,
                interfaceName: "en0", isWiFiPoweredOn: true, ssid: "Test", rssi: -42
            ),
            audio: .unavailable,
            bluetooth: .unavailable
        )
    }

    private func normalizedDegrees(_ degrees: Double) -> Double {
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        return normalized < 0 ? normalized + 360 : normalized
    }
}
