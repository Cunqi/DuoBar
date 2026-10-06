import XCTest
@testable import DuoBarCore

final class MenuBarIconSizeTests: XCTestCase {
    func testDefaultScaleIsOne() {
        XCTAssertEqual(MenuBarIconSize.defaultScale, 1)
        XCTAssertEqual(MenuBarIconSize.resolve(nil), 1)
    }

    func testMissingAndNonFinitePreferencesResolveToDefault() {
        XCTAssertEqual(MenuBarIconSize.resolve(nil), 1)
        XCTAssertEqual(MenuBarIconSize.resolve(.nan), 1)
        XCTAssertEqual(MenuBarIconSize.resolve(.infinity), 1)
        XCTAssertEqual(MenuBarIconSize.resolve(-.infinity), 1)
    }

    func testScaleClampsAndQuantizesToFiveHundredths() {
        XCTAssertEqual(MenuBarIconSize.resolve(0.2), 0.8, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.resolve(1.8), 1.05, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.resolve(0.826), 0.85, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.resolve(0.924), 0.90, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.resolve(1.0), 1.0, accuracy: 0.0001)
    }

    func testStatusItemWidthUsesMinimumAndSharedScalePolicy() {
        XCTAssertEqual(MenuBarIconSize.statusItemWidth(for: 0.80), 22, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.statusItemWidth(for: 1.00), 27, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.statusItemWidth(for: 1.05), 28.35, accuracy: 0.0001)
    }
}
