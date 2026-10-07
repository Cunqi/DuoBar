import Foundation
import XCTest
@testable import DuoBarCore

final class MemoryStressEstimatorTests: XCTestCase {
    func testLowHeadroomAloneIsNotMisrepresentedAsCriticalPressure() {
        XCTAssertEqual(
            MemoryStressEstimator.estimate(headroom: 0.02, compression: 0.1, pageOutsPerSecond: 0),
            .elevated
        )
        XCTAssertEqual(
            MemoryStressEstimator.estimate(headroom: 0.09, compression: 0.32, pageOutsPerSecond: 0),
            .elevated
        )
        XCTAssertEqual(
            MemoryStressEstimator.estimate(headroom: 0.05, compression: 0.46, pageOutsPerSecond: 0),
            .serious
        )
        XCTAssertEqual(
            MemoryStressEstimator.estimate(headroom: 0.02, compression: 0.46, pageOutsPerSecond: 64),
            .critical
        )
    }
}
