import DuoBarCore
import Foundation
import Testing
@testable import DuoBar

@MainActor
struct BrightnessFreshnessRegressionTests {
    @Test("相同亮度持续采样超过四秒仍显示有效亮度")
    func unchangedSuccessfulSamplesRemainFresh() {
        let reader = RegressionBrightnessReader()
        let monitor = makeMonitor(reader: reader)

        for timestamp in [0.0, 1.5, 3.0, 4.5, 6.0] {
            monitor.refresh(at: timestamp)

            #expect(monitor.brightnessSnapshot?.sampledAt == timestamp)
            #expect(fixedBrightness(monitor, at: timestamp) == .adaptive(.brightness(0.60)))
            #expect(monitor.state == .brightness(0.60))
        }
    }

    @Test("小于百分之一的亮度变化刷新新鲜度并保留视觉去重")
    func smallSuccessfulChangesRefreshTimeWithoutRetargetingValue() {
        let reader = RegressionBrightnessReader()
        let monitor = makeMonitor(reader: reader)
        monitor.refresh(at: 0)

        reader.availability = .available(0.606)
        monitor.refresh(at: 4.5)

        #expect(monitor.brightnessSnapshot?.sampledAt == 4.5)
        #expect(fixedBrightness(monitor, at: 4.5) == .adaptive(.brightness(0.60)))

        reader.availability = .available(0.615)
        monitor.refresh(at: 6)

        #expect(monitor.brightnessSnapshot?.sampledAt == 6)
        #expect(fixedBrightness(monitor, at: 6) == .adaptive(.brightness(0.615)))
    }

    @Test("真正读取失败或采样过期时固定亮度降级为无数据")
    func unavailableOrExpiredSamplesUseNeutralFallback() {
        let reader = RegressionBrightnessReader()
        let monitor = makeMonitor(reader: reader)
        monitor.refresh(at: 0)
        #expect(fixedBrightness(monitor, at: 0) == .adaptive(.brightness(0.60)))
        #expect(fixedBrightness(monitor, at: 4.1) == .adaptive(.neutral))

        reader.availability = .unavailable
        monitor.refresh(at: 4.5)
        #expect(fixedBrightness(monitor, at: 4.5) == .adaptive(.neutral))
        #expect(monitor.state == .neutral)

        reader.availability = .available(0.60)
        reader.sampleAge = 5
        monitor.refresh(at: 6)
        #expect(fixedBrightness(monitor, at: 6) == .adaptive(.neutral))
        #expect(monitor.state == .neutral)

        reader.sampleAge = 0
        monitor.refresh(at: 7.5)
        #expect(fixedBrightness(monitor, at: 7.5) == .adaptive(.brightness(0.60)))
    }

    private func makeMonitor(reader: RegressionBrightnessReader) -> AdaptiveRingMonitor {
        AdaptiveRingMonitor(
            performanceSampler: RegressionPerformanceSampler(),
            brightnessReader: reader
        )
    }

    private func fixedBrightness(_ monitor: AdaptiveRingMonitor, at timestamp: TimeInterval) -> RingDisplay {
        RingContentResolver.resolve(
            content: .brightness,
            inputs: monitor.ringInputs(
                hasBattery: true,
                allowsPressureOverride: false,
                volume: .unavailable,
                at: timestamp
            )
        )
    }
}

private final class RegressionBrightnessReader: DisplayBrightnessReading {
    var availability: DisplayBrightnessAvailability = .available(0.60)
    var sampleAge: TimeInterval = 0

    func readMainDisplay(at timestamp: TimeInterval) -> DisplayBrightnessSnapshot {
        DisplayBrightnessSnapshot(
            mainDisplay: MainDisplayDescriptor(displayID: 1, vendorID: 1, productID: 1, serialNumber: 1),
            availability: availability,
            sampledAt: timestamp - sampleAge
        )
    }
}

private struct RegressionPerformanceSampler: PerformanceTelemetrySampling {
    func sample(at timestamp: TimeInterval) -> PerformanceSnapshot {
        PerformanceSnapshot(timestamp: timestamp, cpuLoad: 0.10, memory: nil, thermalState: .nominal)
    }
}
