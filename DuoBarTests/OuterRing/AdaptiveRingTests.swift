@testable import DuoBarKit
import Foundation
import DuoBarCore
import XCTest
@testable import DuoBar

final class AdaptiveRingTests: XCTestCase {
    private let coordinator = AdaptiveRingCoordinator(brightnessMaximumAge: 4)

    func testDebugDesktopSimulationSelectsAdaptiveRing() {
        #if DEBUG
        let context = DeviceContextService().current(simulateDesktop: true)
        XCTAssertFalse(context.hasInternalBattery)
        XCTAssertEqual(context.ringBehavior, .adaptiveRing)
        #endif
    }

    #if DEBUG
    func testSyntheticBrightnessScenariosFlowThroughCoordinator() {
        for (scenario, expected) in [
            (AdaptiveRingSyntheticScenario.brightness25, 0.25),
            (.brightness50, 0.50),
            (.brightness75, 0.75),
            (.brightness100, 1.00)
        ] {
            let input = scenario.input
            let engine = PerformanceDecisionEngine()
            let decision = engine.candidate(for: input.snapshot(at: 0))
            XCTAssertEqual(decision.metric, .idle, scenario.rawValue)
            XCTAssertEqual(resolve(input.brightness), .brightness(expected), scenario.rawValue)
        }
    }

    func testSyntheticNeutralIsUnavailableBrightnessAndIdle() {
        let input = AdaptiveRingSyntheticScenario.neutral.input
        XCTAssertEqual(input.brightness, .unavailable)
        XCTAssertEqual(PerformanceDecisionEngine().candidate(for: input.snapshot(at: 0)).metric, .idle)
        XCTAssertEqual(resolve(input.brightness), .neutral)
        XCTAssertEqual(AdaptiveRingVisualTarget(state: .neutral).progress, 0.25)
    }

    func testSyntheticPerformanceInputsUseProductionEngineCandidates() {
        let scenarios: [(AdaptiveRingSyntheticScenario, PerformanceMetric, PerformanceSeverity)] = [
            (.cpuModerate, .cpu, .elevated), (.cpuHigh, .cpu, .serious), (.cpuVeryHigh, .cpu, .serious),
            (.memoryPressure, .memory, .serious), (.memoryCritical, .memory, .critical),
            (.thermalSerious, .thermal, .serious), (.thermalCritical, .thermal, .critical)
        ]
        for (scenario, metric, severity) in scenarios {
            let candidate = PerformanceDecisionEngine().candidate(for: scenario.input.snapshot(at: 0))
            XCTAssertEqual(candidate.metric, metric, scenario.rawValue)
            XCTAssertEqual(candidate.severity, severity, scenario.rawValue)
        }
    }

    func testSyntheticCPUHighActivatesThroughPersistencePipeline() {
        var engine = PerformanceDecisionEngine()
        let input = AdaptiveRingSyntheticScenario.cpuHigh.input
        _ = engine.update(with: input.snapshot(at: 0))
        _ = engine.update(with: input.snapshot(at: 2))
        let decision = engine.update(with: input.snapshot(at: 4))
        XCTAssertEqual(decision.activeMetric, .cpu)
        XCTAssertEqual(resolve(input.brightness, performance: decision), .performance(metric: .cpu, value: 0.86))
    }

    func testSyntheticSequenceUsesCoordinatorAuthoritativeDecisionPath() {
        let cpu = AdaptiveRingSyntheticSequence.brightnessCPU.steps[1]
        XCTAssertEqual(resolve(cpu.brightness, performance: cpu.decision), .performance(metric: .cpu, value: 0.86))
        let memory = AdaptiveRingSyntheticSequence.escalation.steps[2]
        XCTAssertEqual(resolve(memory.brightness, performance: memory.decision), .performance(metric: .memory, value: 1))
        let thermal = AdaptiveRingSyntheticSequence.escalation.steps[3]
        XCTAssertEqual(resolve(thermal.brightness, performance: thermal.decision), .performance(metric: .thermal, value: 1))
    }

    @MainActor
    func testSyntheticToLiveClearsMonitorDebugInput() {
        let monitor = AdaptiveRingMonitor()
        monitor.useDebugSyntheticScenario(.thermalCritical)
        XCTAssertEqual(monitor.debugTestSource, .synthetic)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .thermal)
        monitor.clearDebugSyntheticInput()
        XCTAssertEqual(monitor.debugTestSource, .live)
        XCTAssertNil(monitor.debugScenarioLabel)
    }

    @MainActor
    func testVisualLabStaticScenarioPreservesEngineForChallengerAndReleaseTiming() {
        let monitor = AdaptiveRingMonitor(brightnessReader: TestBrightnessReader())
        monitor.useDebugSyntheticInput(AdaptiveRingSyntheticScenario.cpuHigh.input, label: "CPU High", preference: .automatic)
        let startedAt = try! XCTUnwrap(monitor.performanceSnapshot?.timestamp)
        monitor.refresh(at: startedAt + 4)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .cpu)
        let generation = monitor.debugEngineGeneration

        monitor.useDebugSyntheticInput(AdaptiveRingSyntheticScenario.memoryPressure.input.with(cpuLoad: 0.86), label: "CPU + Memory", preference: .memory, at: startedAt + 4)
        XCTAssertEqual(monitor.debugEngineGeneration, generation)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .cpu)
        monitor.refresh(at: startedAt + 12)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .cpu)
        monitor.refresh(at: startedAt + 17)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .memory)

        monitor.useDebugSyntheticInput(AdaptiveRingSyntheticScenario.neutral.input, label: "Neutral", preference: .memory, at: startedAt + 17)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .memory)
        monitor.refresh(at: startedAt + 22)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .memory)
        monitor.refresh(at: startedAt + 25)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .idle)
    }

    @MainActor
    func testVisualLabCriticalOverridesPreservedCPUAndResetChangesGeneration() {
        let monitor = AdaptiveRingMonitor(brightnessReader: TestBrightnessReader())
        monitor.useDebugSyntheticInput(AdaptiveRingSyntheticScenario.cpuHigh.input, label: "CPU", preference: .automatic)
        let startedAt = try! XCTUnwrap(monitor.performanceSnapshot?.timestamp)
        monitor.refresh(at: startedAt + 4)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .cpu)
        let generation = monitor.debugEngineGeneration

        monitor.useDebugSyntheticInput(AdaptiveRingSyntheticScenario.thermalCritical.input.with(cpuLoad: 0.86), label: "Thermal", preference: .automatic, at: startedAt + 4)
        XCTAssertEqual(monitor.debugEngineGeneration, generation)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .thermal)
        XCTAssertTrue(monitor.performanceDecision.isCriticalOverride)

        monitor.resetDebugSimulation(input: AdaptiveRingSyntheticScenario.neutral.input, label: "Neutral", preference: .automatic, at: startedAt + 4)
        XCTAssertGreaterThan(monitor.debugEngineGeneration, generation)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .idle)
    }

    @MainActor
    func testLivePreferenceUpdatePreservesSyntheticEngineState() {
        let monitor = AdaptiveRingMonitor(brightnessReader: TestBrightnessReader())
        monitor.useDebugSyntheticInput(AdaptiveRingSyntheticScenario.cpuHigh.input, label: "CPU", preference: .automatic)
        let startedAt = try! XCTUnwrap(monitor.performanceSnapshot?.timestamp)
        monitor.refresh(at: startedAt + 4)
        let generation = monitor.debugEngineGeneration
        monitor.setPreference(.memory)
        XCTAssertEqual(monitor.debugEngineGeneration, generation)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .cpu)
    }

    #endif

    func testAdaptiveRingSettingsDefaultsAndPersistValues() {
        let suite = "DuoBarTests.AdaptiveRingSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(
            PerformancePreference(rawValue: defaults.string(forKey: PreferenceKeys.adaptiveRingPriority) ?? "") ?? .automatic,
            .automatic
        )
        XCTAssertFalse(defaults.bool(forKey: PreferenceKeys.adaptiveRingColorCoding))

        defaults.set(PerformancePreference.memory.rawValue, forKey: PreferenceKeys.adaptiveRingPriority)
        defaults.set(true, forKey: PreferenceKeys.adaptiveRingColorCoding)
        XCTAssertEqual(PerformancePreference(rawValue: defaults.string(forKey: PreferenceKeys.adaptiveRingPriority)!), .memory)
        XCTAssertTrue(defaults.bool(forKey: PreferenceKeys.adaptiveRingColorCoding))
    }

    #if DEBUG
    func testDebugSettingsEligibilityHonorsDesktopSimulationWithoutSeparatePreferences() {
        let macBook = DeviceContext(hasInternalBattery: true)
        XCTAssertFalse(AdaptiveRingSettingsEligibility.isEligible(for: macBook, simulateDesktop: false))
        XCTAssertTrue(AdaptiveRingSettingsEligibility.isEligible(for: macBook, simulateDesktop: true))
        XCTAssertEqual(PreferenceKeys.adaptiveRingColorCoding, "adaptiveRingColorCoding")
        XCTAssertEqual(PreferenceKeys.adaptiveRingPriority, "adaptiveRingPriority")
    }
    #endif

    @MainActor
    func testMonitorUsesOneLeaseAndTimerPerOwner() {
        let monitor = AdaptiveRingMonitor()
        let owner = UUID()
        monitor.acquire(owner: owner, interval: 60)
        monitor.acquire(owner: owner, interval: 60)
        XCTAssertTrue(monitor.isMonitoring)
        XCTAssertEqual(monitor.monitoringOwnerCount, 1)
        monitor.release(owner: owner)
        XCTAssertFalse(monitor.isMonitoring)
        XCTAssertEqual(monitor.monitoringOwnerCount, 0)
    }

    private var display: MainDisplayDescriptor {
        MainDisplayDescriptor(displayID: 1, vendorID: 10, productID: 20, serialNumber: 30)
    }

    private func resolve(
        _ brightness: DisplayBrightnessAvailability,
        performance: PerformanceDecision = .idle
    ) -> AdaptiveRingState {
        coordinator.resolve(
            brightness: DisplayBrightnessSnapshot(
                mainDisplay: display,
                availability: brightness,
                sampledAt: 10
            ),
            performance: performance,
            at: 11
        )
    }

}

private struct TestBrightnessReader: DisplayBrightnessReading {
    func readMainDisplay(at timestamp: TimeInterval) -> DisplayBrightnessSnapshot {
        DisplayBrightnessSnapshot(
            mainDisplay: MainDisplayDescriptor(displayID: 1, vendorID: 1, productID: 1, serialNumber: 1),
            availability: .unavailable,
            sampledAt: timestamp
        )
    }
}
