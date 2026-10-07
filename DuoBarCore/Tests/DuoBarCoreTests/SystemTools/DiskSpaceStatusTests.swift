import XCTest
@testable import DuoBarCore

final class DiskSpaceStatusTests: XCTestCase {
    func testDiskSpaceReportsUsedShareOfTheVolume() {
        let disk = DiskSpaceStatus(totalBytes: 500_000_000_000, availableBytes: 125_000_000_000)

        XCTAssertEqual(disk.usedFraction, 0.75, accuracy: 0.0001)
        XCTAssertEqual(disk.usedPercentage, 75)
        XCTAssertEqual(DiskSpaceStatus(totalBytes: 0, availableBytes: 0).usedFraction, 0)
    }
}
