import XCTest
@testable import DuoBar

final class InfrastructureLifecycleTests: XCTestCase {
    @MainActor
    func testBatteryServicePublishesAnInitialReading() {
        let service = BatteryService()
        var readings: [BatteryStatus] = []
        service.onStatusChange = { readings.append($0) }

        service.start()

        XCTAssertEqual(readings.count, 1)
    }

    func testOnlyOneInstanceLockCanOwnAName() {
        let lockName = "com.mikeli.duobar.tests.\(UUID().uuidString).lock"
        let first = ApplicationInstanceLock(lockFileName: lockName)
        let second = ApplicationInstanceLock(lockFileName: lockName)

        XCTAssertTrue(first.acquire())
        XCTAssertFalse(second.acquire())

        first.release()
        XCTAssertTrue(second.acquire())
    }
}
