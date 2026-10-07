import Foundation
import XCTest
@testable import DuoBarCore

final class AdaptiveRingCoreTests: XCTestCase {
    private let coordinator = AdaptiveRingCoordinator(brightnessMaximumAge: 4)

    func testAvailableBrightnessIsBaselineWhenPerformanceIsIdle() {
        XCTAssertEqual(resolve(.available(0.63)), .brightness(0.63))
    }

    func testUnavailableBrightnessUsesNeutralBaseline() {
        let state = resolve(.unavailable)
        XCTAssertEqual(state, .neutral)
        XCTAssertNil(state.normalizedRingValue)
    }

    func testCPUPerformanceOverridesBrightness() {
        XCTAssertEqual(
            resolve(.available(0.3), performance: decision(.cpu, value: 0.72)),
            .performance(metric: .cpu, value: 0.72)
        )
    }

    func testMemoryPerformanceOverridesBrightness() {
        XCTAssertEqual(
            resolve(.available(0.3), performance: decision(.memory, value: 0.8)),
            .performance(metric: .memory, value: 0.8)
        )
    }

    func testThermalPerformanceOverridesBrightness() {
        XCTAssertEqual(
            resolve(.available(0.3), performance: decision(.thermal, value: 1)),
            .performance(metric: .thermal, value: 1)
        )
    }

    func testPerformanceReleaseReturnsToBrightness() {
        let active = resolve(.available(0.44), performance: decision(.cpu, value: 0.8))
        let released = resolve(.available(0.44), performance: .idle)
        XCTAssertEqual(active, .performance(metric: .cpu, value: 0.8))
        XCTAssertEqual(released, .brightness(0.44))
    }

    func testPerformanceReleaseReturnsToNeutralWhenBrightnessIsUnavailable() {
        XCTAssertEqual(
            resolve(.unavailable, performance: decision(.thermal, value: 0.82)),
            .performance(metric: .thermal, value: 0.82)
        )
        XCTAssertEqual(resolve(.unavailable, performance: .idle), .neutral)
    }

    func testStaleBrightnessUsesNeutralInsteadOfFabricatingZero() {
        let snapshot = DisplayBrightnessSnapshot(
            mainDisplay: display,
            availability: .available(0.7),
            sampledAt: 10
        )
        let state = coordinator.resolve(brightness: snapshot, performance: .idle, at: 15)
        XCTAssertEqual(state, .neutral)
        XCTAssertNil(state.normalizedRingValue)
    }

    func testInvalidBrightnessValuesAreUnavailableRatherThanZero() {
        XCTAssertEqual(DisplayBrightnessResolver.validatedBrightness(-0.01), .unavailable)
        XCTAssertEqual(DisplayBrightnessResolver.validatedBrightness(1.01), .unavailable)
        XCTAssertEqual(DisplayBrightnessResolver.validatedBrightness(.nan), .unavailable)
        XCTAssertEqual(DisplayBrightnessResolver.validatedBrightness(.infinity), .unavailable)
        XCTAssertEqual(DisplayBrightnessResolver.validatedBrightness(0), .available(0))
    }

    func testLinearBrightnessFallbackIsUsedOnlyWhenStandardBrightnessIsUnavailable() {
        XCTAssertEqual(
            DisplayBrightnessResolver.resolvedBrightness(standard: 0.22, linearFallback: 0.81),
            .available(0.22)
        )
        XCTAssertEqual(
            DisplayBrightnessResolver.resolvedBrightness(standard: nil, linearFallback: 0.81),
            .available(0.81)
        )
        XCTAssertEqual(
            DisplayBrightnessResolver.resolvedBrightness(standard: .nan, linearFallback: 0.47),
            .available(0.47)
        )
        XCTAssertEqual(
            DisplayBrightnessResolver.resolvedBrightness(standard: nil, linearFallback: nil),
            .unavailable
        )
    }

    func testMainDisplayIdentityRequiresUniqueMatch() {
        let exact = DisplayHardwareIdentity(vendorID: 10, productID: 20, serialNumber: 30)
        let other = DisplayHardwareIdentity(vendorID: 11, productID: 21, serialNumber: 31)
        XCTAssertEqual(
            DisplayHardwareIdentity.uniqueMatchIndex(for: display, candidates: [other, exact]),
            1
        )
        XCTAssertNil(
            DisplayHardwareIdentity.uniqueMatchIndex(for: display, candidates: [exact, exact])
        )
        XCTAssertNil(
            DisplayHardwareIdentity.uniqueMatchIndex(for: display, candidates: [other])
        )
    }

    func testPresentationTransitionDirectionsAndTimings() {
        let cpu = AdaptiveRingState.performance(metric: .cpu, value: 0.72)

        XCTAssertEqual(
            AdaptiveRingPresentation.transition(from: .neutral, to: cpu),
            AdaptiveRingPresentationTransition(kind: .performanceTakeover, duration: 0.50)
        )
        XCTAssertEqual(
            AdaptiveRingPresentation.transition(from: cpu, to: .neutral),
            AdaptiveRingPresentationTransition(kind: .baselineRelease, duration: 0.60)
        )
        XCTAssertEqual(
            AdaptiveRingPresentation.transition(from: .brightness(0.6), to: cpu).kind,
            .performanceTakeover
        )
        XCTAssertEqual(
            AdaptiveRingPresentation.transition(from: cpu, to: .brightness(0.6)).kind,
            .baselineRelease
        )
    }

    func testPerformanceValueUpdatesRetargetWithoutAnimatingNoOps() {
        XCTAssertEqual(
            AdaptiveRingPresentation.transition(
                from: .performance(metric: .cpu, value: 0.6),
                to: .performance(metric: .cpu, value: 0.75)
            ),
            AdaptiveRingPresentationTransition(kind: .performanceValueUpdate, duration: 0.40)
        )
        XCTAssertEqual(
            AdaptiveRingPresentation.transition(
                from: .performance(metric: .cpu, value: 0.6),
                to: .performance(metric: .cpu, value: 0.603)
            ),
            .none
        )
    }

    func testMetricChangeUsesTakeoverPresentation() {
        XCTAssertEqual(
            AdaptiveRingPresentation.transition(
                from: .performance(metric: .cpu, value: 0.7),
                to: .performance(metric: .memory, value: 0.8)
            ),
            AdaptiveRingPresentationTransition(kind: .performanceMetricChange, duration: 0.45)
        )
    }

    func testMetricIdentificationRespectsHigherPriorityAudioEvent() {
        XCTAssertEqual(
            AdaptiveRingPresentation.metricToIdentify(
                from: .idle,
                to: .cpu,
                hasHigherPriorityEvent: false
            ),
            .cpu
        )
        XCTAssertNil(
            AdaptiveRingPresentation.metricToIdentify(
                from: .idle,
                to: .cpu,
                hasHigherPriorityEvent: true
            )
        )
        XCTAssertNil(
            AdaptiveRingPresentation.metricToIdentify(
                from: .cpu,
                to: .cpu,
                hasHigherPriorityEvent: false
            )
        )
        XCTAssertNil(
            AdaptiveRingPresentation.metricToIdentify(
                from: .cpu,
                to: .idle,
                hasHigherPriorityEvent: false
            )
        )
    }

    func testReduceMotionMakesRingPresentationImmediate() {
        let transition = AdaptiveRingPresentation.transition(
            from: .neutral,
            to: .performance(metric: .thermal, value: 0.82)
        )
        XCTAssertEqual(transition.effectiveDuration(animationsEnabled: true, reduceMotion: true), 0)
        XCTAssertEqual(transition.effectiveDuration(animationsEnabled: false, reduceMotion: false), 0)
        XCTAssertEqual(transition.effectiveDuration(animationsEnabled: true, reduceMotion: false), 0.50)
    }

    func testDiagnosticFormattingNeverShowsNeutralAsSamplingOrPercentage() {
        XCTAssertEqual(
            AdaptiveRingDiagnosticFormatter.visualTarget(.neutral),
            "Neutral baseline · 25.0%"
        )
        XCTAssertEqual(
            AdaptiveRingDiagnosticFormatter.visualTarget(.brightness(0.63)),
            "Brightness · 63.0%"
        )
        XCTAssertEqual(
            AdaptiveRingDiagnosticFormatter.visualTarget(.performance(metric: .memory, value: 0.8)),
            "Memory · 80.0%"
        )
    }

    func testEveryAdaptiveStateMapsToOneNormalizedVisualProgress() {
        XCTAssertEqual(AdaptiveRingVisualTarget(state: .neutral).progress, 0.25)
        XCTAssertEqual(AdaptiveRingVisualTarget(state: .brightness(0.65)).progress, 0.65)
        XCTAssertEqual(
            AdaptiveRingVisualTarget(state: .performance(metric: .cpu, value: 0.82)).progress,
            0.82
        )
        XCTAssertEqual(AdaptiveRingVisualTarget(state: .brightness(1.2)).progress, 1)
        XCTAssertEqual(AdaptiveRingVisualTarget(state: .brightness(-0.2)).progress, 0)
    }

    func testColorResolverKeepsBaselineMonochromeAndUsesMetricRoles() {
        let cpu = colorDecision(.cpu, severity: .elevated)
        XCTAssertEqual(AdaptiveRingColorResolver.resolve(state: .brightness(0.7), decision: cpu, colorCodingEnabled: true).role, .monochrome)
        XCTAssertEqual(AdaptiveRingColorResolver.resolve(state: .neutral, decision: .idle, colorCodingEnabled: true).role, .monochrome)
        XCTAssertEqual(AdaptiveRingColorResolver.resolve(state: .performance(metric: .cpu, value: 0.7), decision: cpu, colorCodingEnabled: false).role, .monochrome)
        XCTAssertEqual(AdaptiveRingColorResolver.resolve(state: .performance(metric: .cpu, value: 0.7), decision: cpu, colorCodingEnabled: true).role, .cpu)
        XCTAssertEqual(AdaptiveRingColorResolver.resolve(state: .performance(metric: .memory, value: 0.8), decision: colorDecision(.memory, severity: .serious), colorCodingEnabled: true).role, .memory)
        XCTAssertEqual(AdaptiveRingColorResolver.resolve(state: .performance(metric: .thermal, value: 1), decision: colorDecision(.thermal, severity: .critical), colorCodingEnabled: true).role, .thermal)
    }

    func testColorIntensityConsumesEngineSeverity() {
        XCTAssertEqual(AdaptiveRingColorResolver.intensity(for: .elevated), 0.68)
        XCTAssertEqual(AdaptiveRingColorResolver.intensity(for: .serious), 0.82)
        XCTAssertEqual(AdaptiveRingColorResolver.intensity(for: .critical), 1)
    }

    func testProductionSettingsEligibilityUsesRealDeviceBehavior() {
        XCTAssertFalse(AdaptiveRingSettingsEligibility.isEligible(for: DeviceContext(hasInternalBattery: true)))
        XCTAssertTrue(AdaptiveRingSettingsEligibility.isEligible(for: DeviceContext(hasInternalBattery: false)))
    }

    func testPresentationStateRetargetsProgressWithoutResettingForSemanticChanges() {
        var presentation = AdaptiveRingPresentationState(state: .neutral)
        XCTAssertEqual(presentation.displayedProgress, 0.25)

        XCTAssertEqual(
            presentation.retarget(to: .performance(metric: .cpu, value: 0.72)).kind,
            .performanceTakeover
        )
        XCTAssertEqual(presentation.displayedProgress, 0.72)

        XCTAssertEqual(
            presentation.retarget(to: .performance(metric: .memory, value: 0.74)).kind,
            .performanceMetricChange
        )
        XCTAssertEqual(presentation.displayedProgress, 0.74)

        XCTAssertEqual(
            presentation.retarget(to: .brightness(0.70)).kind,
            .baselineRelease
        )
        XCTAssertEqual(presentation.displayedProgress, 0.70)
    }

    func testMidAnimationRetargetUsesNewestTargetWithoutAQueuedReset() {
        var presentation = AdaptiveRingPresentationState(state: .neutral)
        _ = presentation.retarget(to: .performance(metric: .cpu, value: 0.72))
        _ = presentation.retarget(to: .performance(metric: .cpu, value: 0.88))
        let transition = presentation.retarget(to: .performance(metric: .cpu, value: 0.61))

        XCTAssertEqual(transition.kind, .performanceValueUpdate)
        XCTAssertEqual(presentation.displayedProgress, 0.61)
        XCTAssertEqual(
            presentation.adaptiveState,
            .performance(metric: .cpu, value: 0.61)
        )
    }

    #if DEBUG
    func testBrightnessDiagnosticClassifiesPublicPipelineFailures() {
        let valid = diagnosticParameter(result: 0, value: 0.6, valid: true)
        let readFailure = diagnosticParameter(result: -536_870_212, value: nil, valid: false)
        let invalid = diagnosticParameter(result: 0, value: 1.2, valid: false)

        XCTAssertEqual(
            diagnosticFailure(framebuffers: 0, selection: .noMatch),
            .framebufferEnumeration
        )
        XCTAssertEqual(
            diagnosticFailure(mainMetadataUsable: false, selection: .noMatch),
            .mainDisplayMetadata
        )
        XCTAssertEqual(
            diagnosticFailure(selection: .noMatch),
            .displayIdentityMatch
        )
        XCTAssertEqual(
            diagnosticFailure(selection: .ambiguousMatch),
            .ambiguousDisplayMatch
        )
        XCTAssertEqual(
            diagnosticFailure(selection: .uniqueMatch, displayServiceResolved: false),
            .displayServiceResolution
        )
        XCTAssertEqual(
            DisplayBrightnessDiagnostic.resolvedSource(
                availability: .available(0.6),
                standardBrightness: valid,
                linearBrightness: .notAttempted
            ),
            .standard
        )
        XCTAssertEqual(
            DisplayBrightnessDiagnostic.resolvedSource(
                availability: .available(0.6),
                standardBrightness: readFailure,
                linearBrightness: valid
            ),
            .linear
        )
        XCTAssertEqual(
            diagnosticFailure(selection: .uniqueMatch, standard: invalid, linear: readFailure),
            .invalidBrightnessValue
        )
        XCTAssertEqual(
            diagnosticFailure(selection: .uniqueMatch, standard: readFailure, linear: readFailure),
            .standardBrightnessRead
        )
    }

    private func diagnosticParameter(result: Int32, value: Double?, valid: Bool) -> DisplayBrightnessParameterDiagnostic {
        DisplayBrightnessParameterDiagnostic(
            attempted: true,
            ioReturn: result,
            value: value,
            isValid: valid
        )
    }

    private func diagnosticFailure(
        framebuffers: Int = 1,
        mainMetadataUsable: Bool = true,
        selection: DisplayBrightnessIdentitySelection,
        displayServiceResolved: Bool? = true,
        standard: DisplayBrightnessParameterDiagnostic = .notAttempted,
        linear: DisplayBrightnessParameterDiagnostic = .notAttempted
    ) -> DisplayBrightnessFailureStage {
        DisplayBrightnessDiagnostic.classifyFailure(
            framebufferCount: framebuffers,
            mainDisplayMetadataIsUsable: mainMetadataUsable,
            selection: selection,
            displayServiceResolved: displayServiceResolved,
            standardBrightness: standard,
            linearBrightness: linear
        )
    }
    #endif

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

    private func decision(_ metric: PerformanceMetric, value: Double) -> PerformanceDecision {
        PerformanceDecision(
            activeMetric: metric,
            severity: .elevated,
            normalizedRingValue: value,
            reason: .cpuSustained,
            candidate: PerformanceCandidate(
                metric: metric,
                severity: .elevated,
                normalizedValue: value,
                reason: .cpuSustained
            )
        )
    }

    private func colorDecision(_ metric: PerformanceMetric, severity: PerformanceSeverity) -> PerformanceDecision {
        PerformanceDecision(
            activeMetric: metric,
            severity: severity,
            normalizedRingValue: severity.normalizedValue,
            reason: .cpuSustained,
            candidate: PerformanceCandidate(metric: metric, severity: severity, normalizedValue: severity.normalizedValue, reason: .cpuSustained)
        )
    }
}
