import SwiftUI

struct DuoGlyphView: View {
    let status: SystemStatus
    var metrics: DuoGlyphMetrics = .standard
    var animationsEnabled = true

    private var glyphState: DuoGlyphState {
        DuoGlyphState(status: status)
    }

    var body: some View {
        ZStack {
            DuoArcShape(
                startDegrees: metrics.arcStartDegrees,
                endDegrees: metrics.arcEndDegrees,
                progress: CGFloat(glyphState.batteryProgress)
            )
            .stroke(
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
            .animation(layerAnimation, value: glyphState.batteryArcOpacity)

            DuoChargingBolt(
                isVisible: glyphState.isCharging,
                size: max(metrics.ringLineWidth * 2.15, 5.2),
                offset: chargingBoltOffset,
                animationsEnabled: animationsEnabled
            )

            DuoCenterGlyph(
                signalLevel: glyphState.wifiLevel,
                size: metrics.wifiSymbolSize,
                animationsEnabled: animationsEnabled
            )
            .offset(y: metrics.wifiYOffset)

            DuoDotRow(
                opacity: glyphState.bluetoothDotOpacity,
                diameter: metrics.dotDiameter,
                spacing: metrics.dotSpacing,
                animationsEnabled: animationsEnabled
            )
            .offset(y: metrics.dotYOffset)
        }
        .frame(width: DuoGlyphMetrics.canvasSize, height: DuoGlyphMetrics.canvasSize)
        .scaleEffect(metrics.overallSize / DuoGlyphMetrics.canvasSize)
        .frame(width: metrics.overallSize, height: metrics.overallSize)
        .foregroundStyle(.primary)
        .accessibilityHidden(true)
    }

    private var arcAnimation: Animation? {
        animationsEnabled ? .easeInOut(duration: 0.32) : nil
    }

    private var layerAnimation: Animation? {
        animationsEnabled ? AnimationConstants.content : nil
    }

    private var chargingBoltOffset: CGSize {
        let progress = min(max(glyphState.batteryProgress, 0.04), 0.72)
        let sweep = metrics.arcEndDegrees - metrics.arcStartDegrees
        let degrees = metrics.arcStartDegrees + sweep * progress
        let radians = degrees * .pi / 180
        let radius = metrics.ringDiameter / 2
        return CGSize(
            width: CGFloat(cos(radians)) * radius,
            height: CGFloat(sin(radians)) * radius + metrics.ringYOffset
        )
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
        let clampedProgress = min(max(progress, 0), 1)
        return startDegrees + (endDegrees - startDegrees) * Double(clampedProgress)
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
    let signalLevel: WiFiSignalLevel
    let size: CGFloat
    let animationsEnabled: Bool

    var body: some View {
        Image(systemName: symbolName, variableValue: signalLevel.symbolVariableValue)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .opacity(symbolOpacity)
            .id(signalLevel)
            .transition(.opacity.combined(with: .scale(scale: 0.82)))
            .frame(width: size * 1.55, height: size * 1.35)
            .animation(animationsEnabled ? AnimationConstants.content : nil, value: signalLevel)
    }

    private var symbolName: String {
        switch signalLevel {
        case .strong, .medium, .weak:
            "wifi"
        case .disconnected, .disabled, .unavailable:
            "wifi.slash"
        }
    }

    private var symbolOpacity: Double {
        signalLevel == .unavailable ? 0.35 : 1
    }
}

struct DuoDotRow: View {
    let opacity: Double
    let diameter: CGFloat
    let spacing: CGFloat
    let animationsEnabled: Bool

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<4, id: \.self) { _ in
                Circle()
                    .frame(width: diameter, height: diameter)
            }
        }
        .opacity(opacity)
        .animation(animationsEnabled ? AnimationConstants.content : nil, value: opacity)
    }
}

private struct DuoChargingBolt: View {
    let isVisible: Bool
    let size: CGFloat
    let offset: CGSize
    let animationsEnabled: Bool

    var body: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: size, weight: .bold))
            .symbolRenderingMode(.monochrome)
            .offset(offset)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.72)
            .animation(animationsEnabled ? AnimationConstants.content : nil, value: isVisible)
    }
}
