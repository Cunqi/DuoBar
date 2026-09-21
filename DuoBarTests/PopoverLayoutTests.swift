import XCTest
@testable import DuoBar

final class PopoverLayoutTests: XCTestCase {
    func testDefaultLayoutHidesBatteryOnMacsWithoutOne() {
        let desktop = PopoverLayout.resolve(stored: nil, hasBattery: false)
        let laptop = PopoverLayout.resolve(stored: nil, hasBattery: true)

        XCTAssertEqual(desktop.entries.map(\.module), PopoverModule.allCases)
        XCTAssertEqual(desktop.visibleModules, PopoverModule.allCases.filter { $0 != .battery })
        XCTAssertEqual(laptop.visibleModules, PopoverModule.allCases)
    }

    func testStoredLayoutKeepsOrderAndVisibility() {
        let layout = PopoverLayout.resolve(stored: "audioOutput:1,network:0,volume:1,battery:1", hasBattery: true)

        XCTAssertEqual(Array(layout.entries.map(\.module).prefix(4)), [.audioOutput, .network, .volume, .battery])
        XCTAssertEqual(Array(layout.visibleModules.prefix(3)), [.audioOutput, .volume, .battery])
    }

    func testModulesMissingFromStoredLayoutAreAppendedAndUnknownOnesDropped() {
        let layout = PopoverLayout.resolve(stored: "volume:1,future:1,network:0", hasBattery: false)

        XCTAssertEqual(Array(layout.entries.map(\.module).prefix(4)), [.volume, .network, .battery, .audioOutput])
        XCTAssertEqual(Array(layout.visibleModules.prefix(2)), [.volume, .audioOutput])
        XCTAssertTrue(layout.visibleModules.contains(.keepAwake))
    }

    func testMalformedStoredValueFallsBackToDefault() {
        XCTAssertEqual(
            PopoverLayout.resolve(stored: "garbage", hasBattery: false),
            PopoverLayout.resolve(stored: nil, hasBattery: false)
        )
    }

    func testMovingAndHidingModulesRoundTripsThroughStorage() {
        var layout = PopoverLayout.resolve(stored: nil, hasBattery: true)
        layout.moveConfigurable(fromOffsets: IndexSet(integer: 3), toOffset: 0, hasBattery: true)
        layout.setVisible(false, for: .volume)

        let restored = PopoverLayout.resolve(stored: layout.storageValue, hasBattery: true)

        XCTAssertEqual(Array(restored.entries.map(\.module).prefix(4)), [.audioOutput, .network, .volume, .battery])
        XCTAssertEqual(Array(restored.visibleModules.prefix(3)), [.audioOutput, .network, .battery])
    }

    func testBatteryIsNeverShownOnMacsWithoutOneEvenIfStoredVisible() {
        let layout = PopoverLayout.resolve(stored: "battery:1,network:1,volume:1,audioOutput:1", hasBattery: false)

        XCTAssertFalse(layout.visibleModules.contains(.battery))
        XCTAssertFalse(layout.configurableEntries(hasBattery: false).map(\.module).contains(.battery))
    }

    func testReorderingInSettingsOnADesktopMovesTheModulesItShows() {
        var layout = PopoverLayout.resolve(stored: nil, hasBattery: false)
        layout.moveConfigurable(fromOffsets: IndexSet(integer: 2), toOffset: 0, hasBattery: false)

        XCTAssertEqual(Array(layout.visibleModules.prefix(3)), [.audioOutput, .network, .volume])
    }
}
