import SwiftUI

struct DuoStatusView: View {
    @ObservedObject private var statusStore: SystemStatusStore
    @ObservedObject private var priorityController: StatusPriorityController
    @ObservedObject private var adaptiveRingMonitor = AdaptiveRingMonitor.shared
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(PreferenceKeys.adaptiveRingColorCoding) private var adaptiveRingColorCoding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var adaptiveRingOwner = UUID()
    @State private var temporaryPerformanceMetric: PerformanceMetric?
    @State private var lastPerformanceMetric: PerformanceMetric?
    @State private var adaptiveRingPresentationState = AdaptiveRingPresentationState()
    @State private var adaptiveRingTransition: AdaptiveRingPresentationTransition = .none

    #if DEBUG
    @AppStorage(DuoGlyphTuningKeys.overallSize) private var overallSize = Double(DuoGlyphMetrics.standard.overallSize)
    @AppStorage(DuoGlyphTuningKeys.ringDiameter) private var ringDiameter = Double(DuoGlyphMetrics.standard.ringDiameter)
    @AppStorage(DuoGlyphTuningKeys.ringLineWidth) private var ringLineWidth = Double(DuoGlyphMetrics.standard.ringLineWidth)
    @AppStorage(DuoGlyphTuningKeys.arcGap) private var arcGap = DuoGlyphMetrics.standard.arcGap
    @AppStorage(DuoGlyphTuningKeys.wifiSymbolSize) private var wifiSymbolSize = Double(DuoGlyphMetrics.standard.wifiSymbolSize)
    @AppStorage(DuoGlyphTuningKeys.wifiYOffset) private var wifiYOffset = Double(DuoGlyphMetrics.standard.wifiYOffset)
    @AppStorage(DuoGlyphTuningKeys.dotDiameter) private var dotDiameter = Double(DuoGlyphMetrics.standard.dotDiameter)
    @AppStorage(DuoGlyphTuningKeys.dotSpacing) private var dotSpacing = Double(DuoGlyphMetrics.standard.dotSpacing)
    @AppStorage(DuoGlyphTuningKeys.dotYOffset) private var dotYOffset = Double(DuoGlyphMetrics.standard.dotYOffset)
    @AppStorage(PreferenceKeys.simulateDesktopMac) private var simulateDesktopMac = false
    #endif

    private let onWidthChange: (CGFloat) -> Void

    init(statusStore: SystemStatusStore, onWidthChange: @escaping (CGFloat) -> Void = { _ in }) {
        self.statusStore = statusStore
        self.priorityController = statusStore.priorityController
        self.onWidthChange = onWidthChange
    }

    private var targetWidth: CGFloat {
        metrics.statusItemWidth
    }

    private var animation: Animation? {
        animationsEnabled ? AnimationConstants.statusMorph : nil
    }

    var body: some View {
        DuoGlyphView(
            status: statusStore.status,
            presentation: priorityController.presentation,
            metrics: metrics,
            animationsEnabled: animationsEnabled,
            ringProgressOverride: adaptiveRingProgress,
            centerStateOverride: performanceCenterState,
            ringTransitionAnimation: adaptiveRingAnimation,
            usesCustomRingTransition: usesAdaptiveRing,
            ringColorOverride: adaptiveRingColor
        )
        .frame(width: targetWidth, height: 22)
        .contentShape(Rectangle())
        .animation(animation, value: targetWidth)
        .onAppear { onWidthChange(targetWidth) }
        .onChange(of: targetWidth) { newValue in onWidthChange(newValue) }
        .onAppear {
            lastPerformanceMetric = adaptiveRingMonitor.performanceDecision.activeMetric
            if usesAdaptiveRing {
                adaptiveRingMonitor.acquire(owner: adaptiveRingOwner)
                adaptiveRingPresentationState.synchronize(to: adaptiveRingMonitor.state)
            }
        }
        .onDisappear { adaptiveRingMonitor.release(owner: adaptiveRingOwner) }
        #if DEBUG
        .onChange(of: simulateDesktopMac) { _ in
            temporaryPerformanceMetric = nil
            lastPerformanceMetric = adaptiveRingMonitor.performanceDecision.activeMetric
            if usesAdaptiveRing {
                adaptiveRingMonitor.acquire(owner: adaptiveRingOwner)
                adaptiveRingPresentationState.synchronize(to: adaptiveRingMonitor.state)
            } else {
                adaptiveRingMonitor.release(owner: adaptiveRingOwner)
            }
        }
        #endif
        .onChange(of: adaptiveRingMonitor.state) { newState in
            guard usesAdaptiveRing else { return }
            let transition = adaptiveRingPresentationState.retarget(to: newState)
            guard transition.kind != .none else { return }
            adaptiveRingTransition = transition
        }
        .onChange(of: adaptiveRingMonitor.performanceDecision.activeMetric) { newMetric in
            guard usesAdaptiveRing else { return }
            let oldMetric = lastPerformanceMetric ?? newMetric
            lastPerformanceMetric = newMetric
            temporaryPerformanceMetric = AdaptiveRingPresentation.metricToIdentify(
                from: oldMetric,
                to: newMetric,
                hasHigherPriorityEvent: priorityController.presentation.event != nil
            )
        }
        .task(id: temporaryPerformanceMetric) {
            guard temporaryPerformanceMetric != nil else { return }
            try? await Task.sleep(for: .seconds(1.35))
            guard !Task.isCancelled else { return }
            temporaryPerformanceMetric = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let network: String
        switch statusStore.status.network.transport {
        case .ethernet:
            network = statusStore.status.network.isConnected ? "Ethernet connected" : "Ethernet disconnected"
        case .wifi:
            network = statusStore.status.network.isConnected ? "Wi-Fi connected" : "Wi-Fi disconnected"
        case .other, .none:
            network = statusStore.status.network.isConnected ? "Network connected" : "Network disconnected"
        }
        let volume: String
        if statusStore.status.audio.volume.isMuted {
            volume = "volume muted"
        } else {
            volume = statusStore.status.audio.volume.percentage.map { "volume \($0) percent" } ?? "volume unavailable"
        }
        let battery = statusStore.status.battery.percentage.map { "battery \($0) percent" } ?? "battery unavailable"
        return "\(network), \(volume), \(battery)"
    }

    private var metrics: DuoGlyphMetrics {
        #if DEBUG
        DuoGlyphMetrics(
            overallSize: CGFloat(overallSize),
            ringDiameter: CGFloat(ringDiameter),
            ringLineWidth: CGFloat(ringLineWidth),
            arcGap: arcGap,
            wifiSymbolSize: CGFloat(wifiSymbolSize),
            wifiYOffset: CGFloat(wifiYOffset),
            dotDiameter: CGFloat(dotDiameter),
            dotSpacing: CGFloat(dotSpacing),
            dotYOffset: CGFloat(dotYOffset)
        )
        #else
        .standard
        #endif
    }

    private var adaptiveRingProgress: Double? {
        guard usesAdaptiveRing else { return nil }
        return adaptiveRingPresentationState.displayedProgress
    }

    private var adaptiveRingAnimation: Animation? {
        guard usesAdaptiveRing else { return nil }
        let duration = adaptiveRingTransition.effectiveDuration(
            animationsEnabled: animationsEnabled,
            reduceMotion: reduceMotion
        )
        return duration > 0
            ? .timingCurve(0.4, 0, 0.2, 1, duration: duration)
            : nil
    }

    private var adaptiveRingColor: Color? {
        guard usesAdaptiveRing else { return nil }
        return AdaptiveRingColorResolver.resolve(
            state: adaptiveRingMonitor.state,
            decision: adaptiveRingMonitor.performanceDecision,
            colorCodingEnabled: adaptiveRingColorCoding
        ).color
    }

    private var performanceCenterState: DuoCenterState? {
        guard usesAdaptiveRing, priorityController.presentation.event == nil else { return nil }
        switch temporaryPerformanceMetric {
        case .cpu: return .performanceCPU
        case .memory: return .performanceMemory
        case .thermal: return .performanceThermal
        case .idle, nil: return nil
        }
    }

    private var usesAdaptiveRing: Bool {
        #if DEBUG
        DeviceContextService()
            .current(simulateDesktop: simulateDesktopMac)
            .ringBehavior == .adaptiveRing
        #else
        DeviceContextService().current().ringBehavior == .adaptiveRing
        #endif
    }
}
