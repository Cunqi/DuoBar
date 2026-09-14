import SwiftUI

struct DuoStatusView: View {
    @ObservedObject private var statusStore: SystemStatusStore
    @ObservedObject private var priorityController: StatusPriorityController
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true

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
            animationsEnabled: animationsEnabled
        )
        .frame(width: targetWidth, height: 22)
        .contentShape(Rectangle())
        .animation(animation, value: targetWidth)
        .onAppear { onWidthChange(targetWidth) }
        .onChange(of: targetWidth) { _, newValue in onWidthChange(newValue) }
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
}
