import XCTest
@testable import DuoBar

final class RingContentTests: XCTestCase {
    private let now: TimeInterval = 100

    private func snapshot(
        cpu: Double? = 0.2,
        availableBytes: UInt64 = 60,
        thermal: PerformanceThermalState = .nominal
    ) -> PerformanceSnapshot {
        PerformanceSnapshot(
            timestamp: now,
            cpuLoad: cpu,
            memory: MemorySnapshot(
                totalBytes: 100,
                availableBytes: availableBytes,
                compressedBytes: 0,
                pageOutsPerSecond: 0,
                stress: .normal
            ),
            thermalState: thermal
        )
    }

    private func brightness(_ availability: DisplayBrightnessAvailability, sampledAt: TimeInterval? = nil) -> DisplayBrightnessSnapshot {
        DisplayBrightnessSnapshot(
            mainDisplay: MainDisplayDescriptor(displayID: 1, vendorID: 1, productID: 1, serialNumber: 1),
            availability: availability,
            sampledAt: sampledAt ?? now
        )
    }

    private func resolve(
        _ content: RingContent,
        hasBattery: Bool = false,
        allowsPressureOverride: Bool = true,
        automaticState: AdaptiveRingState = .neutral,
        snapshot: PerformanceSnapshot? = nil,
        brightness: DisplayBrightnessSnapshot? = nil,
        volume: OutputVolumeStatus = OutputVolumeStatus(level: 0.4, isMuted: false, isSettable: true)
    ) -> RingDisplay {
        RingContentResolver.resolve(
            content: content,
            inputs: RingContentInputs(
                hasBattery: hasBattery,
                allowsPressureOverride: allowsPressureOverride,
                automaticState: automaticState,
                performanceSnapshot: snapshot,
                brightnessSnapshot: brightness,
                volume: volume,
                timestamp: now
            )
        )
    }

    func testBatteryIsOnlyOfferedOnMacsWithABattery() {
        XCTAssertTrue(RingContent.options(hasBattery: true).contains(.battery))
        XCTAssertFalse(RingContent.options(hasBattery: false).contains(.battery))
        XCTAssertEqual(RingContent.options(hasBattery: false).first, .automatic)
    }

    func testAutomaticKeepsTheExistingDeviceBehavior() {
        XCTAssertEqual(resolve(.automatic, hasBattery: true), .battery)
        XCTAssertEqual(
            resolve(.automatic, automaticState: .brightness(0.7)),
            .adaptive(.brightness(0.7))
        )
    }

    func testBatterySelectionFallsBackToAutomaticOnDesktop() {
        XCTAssertEqual(
            resolve(.battery, automaticState: .brightness(0.5)),
            .adaptive(.brightness(0.5))
        )
    }

    func testFixedCPUShowsLiveLoadEvenWithoutPressure() {
        XCTAssertEqual(
            resolve(.cpu, snapshot: snapshot(cpu: 0.2)),
            .adaptive(.performance(metric: .cpu, value: 0.2))
        )
        XCTAssertEqual(resolve(.cpu, snapshot: snapshot(cpu: nil)), .adaptive(.neutral))
    }

    func testFixedMemoryShowsUsedMemory() {
        XCTAssertEqual(
            resolve(.memory, snapshot: snapshot(availableBytes: 25)),
            .adaptive(.performance(metric: .memory, value: 0.75))
        )
    }

    func testFixedThermalShowsEachLevelAsAVisibleStep() {
        let values = PerformanceThermalState.allCases.map { state -> Double? in
            guard case let .adaptive(.performance(.thermal, value)) = resolve(.thermal, snapshot: snapshot(thermal: state)) else {
                return nil
            }
            return value
        }
        XCTAssertEqual(values, [0.25, 0.55, 0.82, 1])
    }

    func testFixedBrightnessIsNeutralWhenUnavailableOrStale() {
        XCTAssertEqual(resolve(.brightness, brightness: brightness(.available(0.6))), .adaptive(.brightness(0.6)))
        XCTAssertEqual(resolve(.brightness, brightness: brightness(.unavailable)), .adaptive(.neutral))
        XCTAssertEqual(resolve(.brightness, brightness: brightness(.available(0.6), sampledAt: now - 10)), .adaptive(.neutral))
        XCTAssertEqual(resolve(.brightness, brightness: nil), .adaptive(.neutral))
    }

    func testFixedVolumeShowsZeroWhenMuted() {
        XCTAssertEqual(resolve(.volume), .adaptive(.volume(0.4)))
        XCTAssertEqual(
            resolve(.volume, volume: OutputVolumeStatus(level: 0.4, isMuted: true, isSettable: true)),
            .adaptive(.volume(0))
        )
        XCTAssertEqual(
            resolve(.volume, volume: OutputVolumeStatus(level: nil, isMuted: false, isSettable: false)),
            .adaptive(.neutral)
        )
    }

    func testPressureTakesOverAFixedMetricOnlyWhenAllowed() {
        let pressure = AdaptiveRingState.performance(metric: .thermal, value: 0.82)

        XCTAssertEqual(
            resolve(.volume, allowsPressureOverride: true, automaticState: pressure),
            .adaptive(pressure)
        )
        XCTAssertEqual(
            resolve(.volume, allowsPressureOverride: false, automaticState: pressure),
            .adaptive(.volume(0.4))
        )
        XCTAssertEqual(
            resolve(.battery, hasBattery: true, allowsPressureOverride: true, automaticState: pressure),
            .battery
        )
    }

    func testReadingDescribesWhatTheRingCurrentlyShows() {
        let inputs = snapshot(cpu: 0.423, availableBytes: 37, thermal: .serious)

        XCTAssertEqual(RingReading(display: .adaptive(.performance(metric: .cpu, value: 0.9)), snapshot: inputs, batteryPercentage: nil), .cpu(percent: 42))
        XCTAssertEqual(RingReading(display: .adaptive(.performance(metric: .memory, value: 0.8)), snapshot: inputs, batteryPercentage: nil), .memory(percent: 63))
        XCTAssertEqual(RingReading(display: .adaptive(.performance(metric: .thermal, value: 0.82)), snapshot: inputs, batteryPercentage: nil), .thermal(.serious))
        XCTAssertEqual(RingReading(display: .adaptive(.brightness(0.5)), snapshot: nil, batteryPercentage: nil), .brightness(percent: 50))
        XCTAssertEqual(RingReading(display: .adaptive(.volume(0.3)), snapshot: nil, batteryPercentage: nil), .volume(percent: 30))
        XCTAssertEqual(RingReading(display: .battery, snapshot: nil, batteryPercentage: 81), .battery(percent: 81))
        XCTAssertEqual(RingReading(display: .adaptive(.neutral), snapshot: nil, batteryPercentage: nil), .unavailable)
    }
}
