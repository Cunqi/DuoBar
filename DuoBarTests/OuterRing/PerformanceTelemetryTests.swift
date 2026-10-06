@testable import DuoBarKit
import Foundation
import DuoBarCore
import XCTest
@testable import DuoBar

final class PerformanceTelemetryTests: XCTestCase {

    func testLiveSamplerProvidesMemoryAndThermalData() async throws {
        let sampler = PerformanceTelemetrySampler()
        let first = sampler.sample()
        try await Task.sleep(for: .milliseconds(50))
        let second = sampler.sample()

        XCTAssertNotNil(first.memory)
        XCTAssertNotNil(second.memory)
        XCTAssertNotNil(second.cpuLoad)
        XCTAssertNil(second.gpuLoad)
        XCTAssertTrue(PerformanceThermalState.allCases.contains(second.thermalState))
    }

    func testDeviceContextMatchesBatteryDetectionAndDebugOverride() {
        let service = DeviceContextService()
        let detected = service.current()
        XCTAssertEqual(
            detected.ringBehavior,
            detected.hasInternalBattery ? .batteryRing : .adaptiveRing
        )

        #if DEBUG
        let simulated = service.current(simulateDesktop: true)
        XCTAssertFalse(simulated.hasInternalBattery)
        XCTAssertEqual(simulated.ringBehavior, .adaptiveRing)
        #endif
    }

    @MainActor
    func testPrototypeMonitorReleasesItsTimer() {
        weak var weakMonitor: PerformancePrototypeMonitor?
        autoreleasepool {
            let monitor = PerformancePrototypeMonitor()
            weakMonitor = monitor
            monitor.start(interval: 60)
        }
        XCTAssertNil(weakMonitor)
    }
}
