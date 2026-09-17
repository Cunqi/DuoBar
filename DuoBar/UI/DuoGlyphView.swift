import AppKit
import SwiftUI

enum BatteryBoltPresentationConstants {
    static let sizeScale: CGFloat = 1.45
    static let opacity = 0.85
    static let sizeMultiplier: CGFloat = 2.15
    static let minimumSize: CGFloat = 5.2
    static let radialOffset: CGFloat = -0.5
}

struct DuoGlyphView: View {
    let status: SystemStatus
    var presentation: StatusPresentation = .normal
    var metrics: DuoGlyphMetrics = .standard
    var animationsEnabled = true
    var ringProgressOverride: Double?
    var centerStateOverride: DuoCenterState?
    var ringTransitionAnimation: Animation?
    var usesCustomRingTransition = false
    var ringColorOverride: Color?
    var batteryColorCodingEnabled = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var centerPulseScale: CGFloat = 1

    private var glyphState: DuoGlyphState {
        DuoGlyphState(
            status: status,
            presentation: presentation,
            ringProgressOverride: ringProgressOverride,
            centerStateOverride: centerStateOverride,
            batteryColorCodingEnabled: batteryColorCodingEnabled
        )
    }

    var body: some View {
        ZStack {
            DuoArcShape(
                startDegrees: metrics.arcStartDegrees,
                endDegrees: metrics.arcEndDegrees,
                progress: CGFloat(glyphState.batteryProgress)
            )
            .stroke(
                arcColor,
                style: StrokeStyle(
                    lineWidth: metrics.ringLineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: metrics.ringDiameter, height: metrics.ringDiameter)
            .offset(y: metrics.ringYOffset)
            .opacity(glyphState.batteryArcOpacity)
            .animation(arcAnimation, value: glyphState.batteryProgress)
            .animation(arcOpacityAnimation, value: glyphState.batteryArcOpacity)

            DuoChargingBolt(
                isVisible: glyphState.batteryPresentation.boltPlacement != .none,
                size: chargingBoltSize,
                offset: chargingBoltOffset,
                color: arcColor,
                opacity: chargingBoltOpacity,
                animationsEnabled: motionAllowed
            )

            DuoCenterTransitionView(
                targetState: glyphState.centerState,
                size: metrics.wifiSymbolSize,
                pulseScale: centerPulseScale,
                animationsEnabled: animationsEnabled,
                reduceMotion: reduceMotion
            )
            .offset(y: metrics.wifiYOffset)

            DuoDotRow(
                activeCount: glyphState.volumeActiveDotCount,
                diameter: metrics.dotDiameter,
                spacing: metrics.dotSpacing,
                animationsEnabled: motionAllowed
            )
            .offset(y: metrics.dotYOffset)
        }
        .frame(width: DuoGlyphMetrics.canvasSize, height: DuoGlyphMetrics.canvasSize)
        .scaleEffect(metrics.overallSize / DuoGlyphMetrics.canvasSize)
        .frame(width: metrics.overallSize, height: metrics.overallSize)
        .accessibilityHidden(true)
        .task(id: glyphState.audioEventID) {
            centerPulseScale = 1
            guard glyphState.audioEventID != nil, motionAllowed else { return }
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.1)) {
                centerPulseScale = 1.055
            }
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else {
                centerPulseScale = 1
                return
            }
            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                centerPulseScale = 1
            }
        }
    }

    private var motionAllowed: Bool {
        animationsEnabled && !reduceMotion
    }

    private var arcColor: Color {
        if ringProgressOverride != nil {
            return ringColorOverride ?? .primary
        }

        switch glyphState.batteryPresentation.colorRole {
        case .charging: return Color(nsColor: .systemGreen)
        case .lowPowerMode: return Color(nsColor: .systemYellow)
        case .lowBattery: return Color(nsColor: .systemRed)
        case .monochrome: break
        }

        switch glyphState.feedback {
        case .charging, .lowBattery: return .primary
        case .none, .audioConnected: return ringColorOverride ?? .primary
        }
    }

    private var arcAnimation: Animation? {
        guard motionAllowed else { return nil }
        return usesCustomRingTransition ? ringTransitionAnimation : .easeInOut(duration: 0.32)
    }

    private var arcOpacityAnimation: Animation? {
        guard motionAllowed else { return nil }
        return usesCustomRingTransition ? ringTransitionAnimation : layerAnimation
    }

    private var layerAnimation: Animation? {
        motionAllowed ? AnimationConstants.content : nil
    }

    private var chargingBoltOffset: CGSize {
        let point: CGPoint
        switch glyphState.batteryPresentation.boltPlacement {
        case .ringEndpoint:
            point = DuoRingGeometry.endpoint(
                metrics: metrics,
                progress: glyphState.batteryProgress,
                radialOffset: chargingBoltRadialOffset
            )
        case .ringMidpoint:
            point = DuoRingGeometry.midpoint(
                metrics: metrics,
                radialOffset: chargingBoltRadialOffset
            )
        case .none:
            point = .zero
        }
        return CGSize(
            width: point.x,
            height: point.y
        )
    }

    private var chargingBoltSize: CGFloat {
        max(
            metrics.ringLineWidth * BatteryBoltPresentationConstants.sizeMultiplier,
            BatteryBoltPresentationConstants.minimumSize
        ) * BatteryBoltPresentationConstants.sizeScale
    }

    private var chargingBoltOpacity: Double {
        BatteryBoltPresentationConstants.opacity
    }

    private var chargingBoltRadialOffset: CGFloat {
        BatteryBoltPresentationConstants.radialOffset
    }
}

enum DuoRingGeometry {
    static func endDegrees(startDegrees: Double, endDegrees: Double, progress: Double) -> Double {
        let clampedProgress = min(max(progress, 0), 1)
        return startDegrees + (endDegrees - startDegrees) * clampedProgress
    }

    static func endpoint(
        metrics: DuoGlyphMetrics,
        progress: Double,
        radialOffset: CGFloat = 0
    ) -> CGPoint {
        let degrees = endDegrees(
            startDegrees: metrics.arcStartDegrees,
            endDegrees: metrics.arcEndDegrees,
            progress: progress
        )
        let radians = degrees * .pi / 180
        let radius = metrics.ringDiameter / 2 + radialOffset
        return CGPoint(
            x: CGFloat(cos(radians)) * radius,
            y: CGFloat(sin(radians)) * radius + metrics.ringYOffset
        )
    }

    static func midpoint(metrics: DuoGlyphMetrics, radialOffset: CGFloat = 0) -> CGPoint {
        endpoint(metrics: metrics, progress: 0.5, radialOffset: radialOffset)
    }
}

struct DuoCenterTransitionView: View {
    let targetState: DuoCenterState
    let size: CGFloat
    let pulseScale: CGFloat
    let animationsEnabled: Bool
    let reduceMotion: Bool

    @State private var displayedState: DuoCenterState
    @State private var outgoingState: DuoCenterState?
    @State private var transitionProgress: CGFloat = 1

    init(
        targetState: DuoCenterState,
        size: CGFloat,
        pulseScale: CGFloat,
        animationsEnabled: Bool,
        reduceMotion: Bool
    ) {
        self.targetState = targetState
        self.size = size
        self.pulseScale = pulseScale
        self.animationsEnabled = animationsEnabled
        self.reduceMotion = reduceMotion
        _displayedState = State(initialValue: targetState)
    }

    var body: some View {
        DuoCenterTransitionLayer(
            outgoingState: outgoingState,
            incomingState: displayedState,
            progress: transitionProgress,
            pulseScale: pulseScale,
            size: size,
            usesSpatialMotion: !reduceMotion
        )
        .onChange(of: targetState) { newState in
            transition(to: newState)
        }
        .task(id: targetState) {
            try? await Task.sleep(for: .milliseconds(270))
            guard !Task.isCancelled else { return }
            outgoingState = nil
        }
    }

    private func transition(to newState: DuoCenterState) {
        guard newState != displayedState else { return }
        guard animationsEnabled else {
            outgoingState = nil
            displayedState = newState
            transitionProgress = 1
            return
        }

        outgoingState = displayedState
        displayedState = newState
        transitionProgress = 0
        withAnimation(.easeInOut(duration: 0.25)) {
            transitionProgress = 1
        }
    }
}

struct DuoCenterTransitionLayer: View {
    let outgoingState: DuoCenterState?
    let incomingState: DuoCenterState
    let progress: CGFloat
    let pulseScale: CGFloat
    let size: CGFloat
    let usesSpatialMotion: Bool

    var body: some View {
        ZStack {
            if let outgoingState {
                DuoCenterGlyph(state: outgoingState, size: size)
                    .opacity(1 - progress)
                    .scaleEffect(usesSpatialMotion ? 1 - (0.1 * progress) : 1)
                    .offset(
                        x: usesSpatialMotion ? -travelDistance * progress : 0,
                        y: usesSpatialMotion ? -travelDistance * progress : 0
                    )
            }

            DuoCenterGlyph(state: incomingState, size: size)
                .opacity(progress)
                .scaleEffect((usesSpatialMotion ? 0.9 + (0.1 * progress) : 1) * incomingPulseScale)
                .offset(
                    x: usesSpatialMotion ? travelDistance * (1 - progress) : 0,
                    y: usesSpatialMotion ? travelDistance * (1 - progress) : 0
                )
        }
        .frame(width: size * 1.65, height: size * 1.4)
    }

    private var incomingPulseScale: CGFloat {
        incomingState.isTemporaryAudioState ? pulseScale : 1
    }

    // The standard glyph is scaled from a 32 pt design canvas to 24 pt in the menu bar.
    // This produces an effective two-point displacement at the installed size.
    private var travelDistance: CGFloat {
        size * 0.215
    }
}

struct DuoArcShape: Shape {
    let startDegrees: Double
    let endDegrees: Double
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var visibleEndDegrees: Double {
        DuoRingGeometry.endDegrees(
            startDegrees: startDegrees,
            endDegrees: endDegrees,
            progress: Double(progress)
        )
    }

    func path(in rect: CGRect) -> Path {
        let clampedProgress = min(max(progress, 0), 1)
        guard clampedProgress > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let sampleCount = 72

        var path = Path()
        for index in 0...sampleCount {
            let sampleProgress = Double(index) / Double(sampleCount)
            let degrees = startDegrees + (visibleEndDegrees - startDegrees) * sampleProgress
            let radians = degrees * .pi / 180
            let point = CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

struct DuoCenterGlyph: View {
    let state: DuoCenterState
    let size: CGFloat

    var body: some View {
        Image(systemName: symbolName, variableValue: variableValue)
            .font(.system(size: symbolSize, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(glyphColor)
            .opacity(symbolOpacity)
            .frame(width: size * 1.65, height: size * 1.4)
    }

    private var symbolName: String {
        switch state {
        case .wifi: "wifi"
        case .ethernet: "cable.connector.horizontal"
        case .offline: "network.slash"
        case .other: "ellipsis.circle"
        case .unavailable: "network.slash"
        case .airPodsPro: "airpodspro"
        case .airPodsMax: "airpodsmax"
        case .airPods: "airpods"
        case .headphones: "headphones"
        case .audioDevice: "speaker.wave.2"
        case .performanceCPU: "cpu"
        case .performanceMemory: "memorychip"
        case .performanceThermal: "thermometer.medium"
        }
    }

    private var variableValue: Double? {
        guard case let .wifi(level) = state else { return nil }
        return level.symbolVariableValue
    }

    private var symbolSize: CGFloat {
        switch state {
        case .ethernet, .other, .airPodsPro, .airPodsMax, .airPods, .headphones, .audioDevice,
             .performanceCPU, .performanceMemory, .performanceThermal:
            size * 0.92
        case .wifi, .offline, .unavailable: size
        }
    }

    private var symbolOpacity: Double {
        state == .unavailable ? 0.34 : 1
    }

    private var glyphColor: Color {
        state.isTemporaryAudioState ? .accentColor.opacity(0.86) : .primary
    }
}

private extension DuoCenterState {
    var isTemporaryAudioState: Bool {
        switch self {
        case .airPodsPro, .airPodsMax, .airPods, .headphones, .audioDevice: true
        case .wifi, .ethernet, .offline, .other, .unavailable,
             .performanceCPU, .performanceMemory, .performanceThermal:
            false
        }
    }
}

struct DuoDotRow: View {
    let activeCount: Int?
    let diameter: CGFloat
    let spacing: CGFloat
    let animationsEnabled: Bool

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .frame(width: diameter, height: diameter)
                    .opacity(opacity(for: index))
            }
        }
        .foregroundStyle(.primary)
        .animation(animationsEnabled ? AnimationConstants.content : nil, value: activeCount)
    }

    private func opacity(for index: Int) -> Double {
        guard let activeCount else { return 0.28 }
        return index < activeCount ? 1 : 0.16
    }
}

private struct DuoChargingBolt: View {
    let isVisible: Bool
    let size: CGFloat
    let offset: CGSize
    let color: Color
    let opacity: Double
    let animationsEnabled: Bool

    var body: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: size, weight: .bold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color)
            .offset(offset)
            .opacity(isVisible ? opacity : 0)
            .scaleEffect(isVisible ? 1 : 0.72)
            .animation(animationsEnabled ? AnimationConstants.content : nil, value: isVisible)
            .animation(animationsEnabled ? AnimationConstants.content : nil, value: offset)
    }
}
