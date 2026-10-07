import XCTest
@testable import DuoBarCore

final class BatteryRingPresentationTests: XCTestCase {
    func testColorCodingDefaultsToMonochrome() {
        XCTAssertEqual(presentation(percentage: 10, colorCoding: false).colorRole, .monochrome)
        XCTAssertEqual(presentation(percentage: 10, charging: true, colorCoding: false).colorRole, .monochrome)
    }

    func testChargingTakesColorPriority() {
        XCTAssertEqual(presentation(percentage: 15, charging: true, lowPowerMode: true).colorRole, .charging)
    }

    func testFullPluggedUsesChargingColor() {
        XCTAssertEqual(
            presentation(percentage: 100, charging: true, pluggedIn: true, fullyCharged: true).colorRole,
            .charging
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

    func testFinalExternalPowerColorPriorityMatrix() {
        XCTAssertEqual(
            presentation(percentage: 50, pluggedIn: true, colorCoding: true),
            BatteryRingPresentation(boltPlacement: .topGap, colorRole: .charging)
        )
        XCTAssertEqual(
            presentation(percentage: 50, pluggedIn: true, colorCoding: false),
            BatteryRingPresentation(boltPlacement: .topGap, colorRole: .monochrome)
        )
        XCTAssertEqual(
            presentation(percentage: 15, pluggedIn: true, lowPowerMode: true, colorCoding: true),
            BatteryRingPresentation(boltPlacement: .topGap, colorRole: .charging)
        )
        XCTAssertEqual(
            presentation(percentage: 15, pluggedIn: true, lowPowerMode: true, colorCoding: false),
            BatteryRingPresentation(boltPlacement: .topGap, colorRole: .monochrome)
        )
        XCTAssertEqual(presentation(percentage: 15, lowPowerMode: true).colorRole, .lowPowerMode)
        XCTAssertEqual(presentation(percentage: 15).colorRole, .lowBattery)
        XCTAssertEqual(presentation(percentage: 100, pluggedIn: true).colorRole, .charging)
        XCTAssertEqual(
            presentation(percentage: 100, pluggedIn: true, colorCoding: false).colorRole,
            .monochrome
        )
        XCTAssertEqual(presentation(percentage: 100).boltPlacement, .none)
    }

    func testPluggedStateIsAuthoritativeEvenWhenChargingIsPaused() {
        let paused = presentation(
            percentage: 80,
            charging: false,
            pluggedIn: true,
            fullyCharged: false,
            colorCoding: true
        )
        XCTAssertEqual(paused.boltPlacement, .topGap)
        XCTAssertEqual(paused.colorRole, .charging)
    }

    func testChargingBelowFullUsesTopGapBolt() {
        XCTAssertEqual(presentation(percentage: 20, charging: true).boltPlacement, .topGap)
    }

    func testUnpluggedBatteryHasNoBolt() {
        XCTAssertEqual(presentation(percentage: 80).boltPlacement, .none)
    }

    func testPluggedChargingPauseStillUsesTopGapBolt() {
        XCTAssertEqual(presentation(percentage: 50, pluggedIn: true).boltPlacement, .topGap)
    }

    func testFullConnectedBatteryUsesSameTopGapBolt() {
        XCTAssertEqual(
            presentation(percentage: 100, pluggedIn: true, fullyCharged: true).boltPlacement,
            .topGap
        )
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
                isPluggedIn: pluggedIn || charging,
                isFullyCharged: fullyCharged,
                isAvailable: true,
                isLowPowerModeEnabled: lowPowerMode
            ),
            colorCodingEnabled: colorCoding
        )
    }
}
