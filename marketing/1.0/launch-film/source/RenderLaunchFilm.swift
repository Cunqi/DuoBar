import AppKit
import AVFoundation
import CoreGraphics
import SwiftUI

private enum Film {
    static let width = 1_920
    static let height = 1_080
    static let fps: Int32 = 60
    static let duration = 20.5
    static let frameCount = Int(duration * Double(fps))

    static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("marketing/1.0/launch-film", isDirectory: true)
    static let finalDirectory = root.appendingPathComponent("final", isDirectory: true)
    static let visualMasterURL = finalDirectory.appendingPathComponent(".DuoBar-1.0-Official-visual-master.mp4")
    static let contactSheetURL = finalDirectory.appendingPathComponent("DuoBar-1.0-Official-Launch-Film-contact-sheet.png")
    static let posterURL = finalDirectory.appendingPathComponent("DuoBar-1.0-Launch-Poster.png")
}

private struct CubicBezier {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double

    func value(at input: Double) -> Double {
        let target = min(max(input, 0), 1)
        var lower = 0.0
        var upper = 1.0
        var parameter = target
        for _ in 0..<18 {
            let x = component(parameter, a: x1, b: x2)
            if abs(x - target) < 0.000_001 { break }
            if x < target { lower = parameter } else { upper = parameter }
            parameter = (lower + upper) * 0.5
        }
        return component(parameter, a: y1, b: y2)
    }

    private func component(_ t: Double, a: Double, b: Double) -> Double {
        let inverse = 1 - t
        return 3 * inverse * inverse * t * a + 3 * inverse * t * t * b + t * t * t
    }
}

private enum Timing {
    static let reveal = CubicBezier(x1: 0.55, y1: 0.0, x2: 0.26, y2: 1.0)
    static let camera = CubicBezier(x1: 0.30, y1: 0.0, x2: 0.16, y2: 1.0)
    static let resolve = CubicBezier(x1: 0.20, y1: 0.0, x2: 0.22, y2: 1.0)
    static let withdraw = CubicBezier(x1: 0.42, y1: 0.0, x2: 0.72, y2: 1.0)
    static let type = CubicBezier(x1: 0.18, y1: 0.0, x2: 0.24, y2: 1.0)

    static func progress(_ time: Double, _ start: Double, _ duration: Double, _ curve: CubicBezier = resolve) -> Double {
        curve.value(at: (time - start) / duration)
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ progress: Double) -> CGFloat {
        a + (b - a) * CGFloat(progress)
    }
}

private struct ProductionArc: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        let amount = min(max(progress, 0), 1)
        guard amount > 0 else { return Path() }
        let start = 145.0
        let end = start + 250.0 * amount
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.5
        var path = Path()
        for index in 0...220 {
            let unit = Double(index) / 220.0
            let radians = (start + (end - start) * unit) * .pi / 180.0
            let point = CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }
}

private enum CenterKind: Equatable {
    case wifi
    case ethernet
    case airPodsPro

    var symbol: String {
        switch self {
        case .wifi: "wifi"
        case .ethernet: "cable.connector.horizontal"
        case .airPodsPro: "airpodspro"
        }
    }

    var relativeSize: CGFloat {
        switch self {
        case .wifi: 1.0
        case .ethernet, .airPodsPro: 0.92
        }
    }
}

private struct CenterLayer: View {
    let kind: CenterKind
    let size: CGFloat
    let opacity: Double
    let scale: Double
    let offset: CGSize
    let reveal: Double
    let transitionSoftness: Double

    var body: some View {
        Image(systemName: kind.symbol, variableValue: kind == .wifi ? 1 : nil)
            .font(.system(size: size * kind.relativeSize, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(kind == .airPodsPro ? Color.accentColor.opacity(0.82) : Color.white.opacity(0.94))
            .frame(width: size * 1.65, height: size * 1.4)
            .mask {
                Ellipse()
                    .frame(
                        width: max(1, size * 1.78 * reveal),
                        height: max(1, size * 1.58 * reveal)
                    )
                    .blur(radius: max(0.25, size * 0.022))
            }
            .scaleEffect(scale)
            .offset(offset)
            .blur(radius: size * 0.010 * transitionSoftness)
            .opacity(opacity)
    }
}

private struct GlyphTransition {
    let outgoing: CenterKind
    let incoming: CenterKind
    let progress: Double
}

private struct CinematicGlyph: View {
    let size: CGFloat
    let arcReveal: Double
    let batteryLevel: Double
    let networkReveal: Double
    let dotReveals: [Double]
    let dotActivity: [Double]
    let center: CenterKind
    let transition: GlyphTransition?
    let intensity: Double

    private var ringDiameter: CGFloat { size * (19.875 / 24.0) }
    private var ringLineWidth: CGFloat { size * (2.1 / 24.0) }
    private var ringYOffset: CGFloat { size * (-0.6 / 24.0) }
    private var symbolSize: CGFloat { size * (9.3 / 24.0) }
    private var symbolYOffset: CGFloat { size * (-0.9375 / 24.0) }
    private var dotDiameter: CGFloat { size * (2.175 / 24.0) }
    private var dotSpacing: CGFloat { size * (1.35 / 24.0) }
    private var dotYOffset: CGFloat { size * (8.4 / 24.0) }

    var body: some View {
        ZStack {
            ProductionArc(progress: 1)
                .stroke(Color.white.opacity(0.022 * intensity), style: strokeStyle)
                .frame(width: ringDiameter, height: ringDiameter)
                .offset(y: ringYOffset)

            ProductionArc(progress: min(arcReveal, batteryLevel))
                .stroke(Color.white.opacity(0.94 * intensity), style: strokeStyle)
                .frame(width: ringDiameter, height: ringDiameter)
                .offset(y: ringYOffset)

            centerGeometry

            HStack(spacing: dotSpacing) {
                ForEach(0..<4, id: \.self) { index in
                    let reveal = dotReveals[index]
                    let activity = dotActivity[index]
                    Circle()
                        .fill(Color.white.opacity((0.18 + 0.74 * activity) * reveal * intensity))
                        .frame(width: dotDiameter, height: dotDiameter)
                        .scaleEffect(0.76 + 0.24 * reveal)
                        .offset(y: size * 0.018 * (1 - reveal))
                }
            }
            .offset(y: dotYOffset)
        }
        .frame(width: size, height: size)
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: ringLineWidth, lineCap: .round, lineJoin: .round)
    }

    @ViewBuilder
    private var centerGeometry: some View {
        if let transition {
            let p = transition.progress
            let outProgress = Timing.withdraw.value(at: min(1, p / 0.88))
            let inProgress = Timing.resolve.value(at: max(0, (p - 0.16) / 0.84))
            let overlapSoftness = sin(.pi * min(max(p, 0), 1))
            CenterLayer(
                kind: transition.outgoing,
                size: symbolSize,
                opacity: 1 - outProgress,
                scale: 1 - 0.14 * outProgress,
                offset: CGSize(width: -size * 0.014 * outProgress, height: -size * 0.014 * outProgress),
                reveal: max(0.025, 1 - outProgress),
                transitionSoftness: overlapSoftness
            )
            .offset(y: symbolYOffset)

            CenterLayer(
                kind: transition.incoming,
                size: symbolSize,
                opacity: inProgress,
                scale: 0.86 + 0.14 * inProgress,
                offset: CGSize(width: size * 0.014 * (1 - inProgress), height: size * 0.014 * (1 - inProgress)),
                reveal: max(0.025, inProgress),
                transitionSoftness: overlapSoftness
            )
            .offset(y: symbolYOffset)
        } else {
            CenterLayer(
                kind: center,
                size: symbolSize,
                opacity: networkReveal,
                scale: 0.97 + 0.03 * networkReveal,
                offset: CGSize(width: 0, height: size * 0.012 * (1 - networkReveal)),
                reveal: networkReveal,
                transitionSoftness: 0
            )
            .offset(y: symbolYOffset)
        }
    }
}

private struct MenuBarContext: View {
    let progress: Double
    let glyphOpacity: Double

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color(red: 0.052, green: 0.061, blue: 0.075).opacity(0.98 * progress))
                .frame(height: 84)

            Rectangle()
                .fill(Color.white.opacity(0.055 * progress))
                .frame(height: 1)
                .offset(y: 83)

            HStack(spacing: 28) {
                Text("DuoBar")
                    .fontWeight(.semibold)
                Text("File")
                Text("Edit")
                Text("Window")
                Text("Help")
            }
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(Color.white.opacity(0.54 * progress * glyphOpacity))
            .position(x: 228, y: 41)

            HStack(spacing: 27) {
                Image(systemName: "magnifyingglass")
                Image(systemName: "switch.2")
                Text("9:41")
                    .font(.system(size: 18, weight: .medium))
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.62 * progress * glyphOpacity))
            .position(x: 1_705, y: 41)
        }
        .frame(width: 1_920, height: 1_080, alignment: .top)
        .opacity(progress)
    }
}

private struct LaunchFrame: View {
    let time: Double

    private var formation: Double { Timing.progress(time, 0.25, 5.75, Timing.camera) }
    private var arcReveal: Double { Timing.progress(time, 0.62, 4.55, Timing.reveal) }
    private var networkReveal: Double { Timing.progress(time, 3.0, 1.55, Timing.resolve) }
    private var initialDots: [Double] {
        [4.5, 4.875, 5.25, 5.625].map { Timing.progress(time, $0, 0.46, Timing.resolve) }
    }
    private var contextProgress: Double { Timing.progress(time, 14.25, 1.5, Timing.camera) }
    private var brandProgress: Double { Timing.progress(time, 17.25, 1.05, Timing.camera) }

    private var microCameraProgress: Double {
        guard time >= 7.0 else { return 0 }
        return Timing.progress(time, 7.0, 7.0, CubicBezier(x1: 0.34, y1: 0.08, x2: 0.66, y2: 0.92))
    }

    private var glyphSize: CGFloat {
        if time < 14.25 {
            return Timing.lerp(2_150, 410, formation) * (1 + 0.012 * microCameraProgress)
        }
        if time < 17.25 { return Timing.lerp(410, 34, contextProgress) }
        return Timing.lerp(34, 320, brandProgress)
    }

    private var glyphPosition: CGPoint {
        if time < 14.25 {
            var position = CGPoint(
                x: Timing.lerp(1_125, 960, formation),
                y: Timing.lerp(505, 510, formation)
            )
            position.x += Timing.lerp(-4, 5, microCameraProgress)
            position.y += Timing.lerp(1, -3, microCameraProgress)
            return position
        }
        if time < 17.25 {
            var position = CGPoint(
                x: Timing.lerp(960, 1_525, contextProgress),
                y: Timing.lerp(510, 41, contextProgress)
            )
            position.x += Timing.lerp(-4, 5, microCameraProgress)
            position.y += Timing.lerp(1, -3, microCameraProgress)
            return position
        }
        return CGPoint(
                x: Timing.lerp(1_525, 600, brandProgress),
                y: Timing.lerp(41, 535, brandProgress)
        )
    }

    private var batteryLevel: Double {
        if time < 6.75 { return 1 }
        if time < 7.65 { return 1 - 0.30 * Timing.progress(time, 6.75, 0.90, Timing.resolve) }
        if time < 9.1 { return 0.70 + 0.22 * Timing.progress(time, 8.25, 0.85, Timing.resolve) }
        return 0.92
    }

    private var dotActivity: [Double] {
        if time < 6.25 { return [1, 1, 1, 1] }
        let reset = 1 - Timing.progress(time, 6.25, 0.38, Timing.resolve)
        return [
            1,
            max(reset, Timing.progress(time, 7.50, 0.28, Timing.resolve)),
            max(reset, Timing.progress(time, 7.875, 0.28, Timing.resolve)),
            max(reset, Timing.progress(time, 8.25, 0.28, Timing.resolve)),
        ]
    }

    private var centerState: CenterKind {
        if time >= 10.41 && time < 10.875 { return .ethernet }
        if time >= 12.66 && time < 13.125 { return .airPodsPro }
        return .wifi
    }

    private var centerTransition: GlyphTransition? {
        let events: [(Double, Double, CenterKind, CenterKind)] = [
            (9.75, 0.66, .wifi, .ethernet),
            (10.875, 0.66, .ethernet, .wifi),
            (12.0, 0.66, .wifi, .airPodsPro),
            (13.125, 0.66, .airPodsPro, .wifi),
        ]
        for event in events where time >= event.0 && time < event.0 + event.1 {
            return GlyphTransition(
                outgoing: event.2,
                incoming: event.3,
                progress: Timing.progress(time, event.0, event.1, Timing.resolve)
            )
        }
        return nil
    }

    private var contextVisibility: Double {
        contextProgress * (1 - Timing.progress(time, 17.05, 0.65, Timing.resolve))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.010, green: 0.014, blue: 0.020)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.024),
                    Color(red: 0.03, green: 0.045, blue: 0.063).opacity(0.018),
                    Color.clear,
                ],
                center: UnitPoint(x: glyphPosition.x / 1_920, y: glyphPosition.y / 1_080),
                startRadius: 0,
                endRadius: 790
            )

            MenuBarContext(progress: contextVisibility, glyphOpacity: 1 - brandProgress)

            // The 15.75 s frame is the shared visual/audio resolution point.
            // This is a tonal landing cue, not a glow or an extra UI state.
            RadialGradient(
                colors: [Color.white.opacity(0.045), Color.clear],
                center: UnitPoint(x: glyphPosition.x / 1_920, y: glyphPosition.y / 1_080),
                startRadius: 0,
                endRadius: 110
            )
            .opacity(
                Timing.progress(time, 15.58, 0.17, Timing.resolve)
                * (1 - Timing.progress(time, 15.75, 0.24, Timing.resolve))
                * contextVisibility
            )
            .allowsHitTesting(false)

            CinematicGlyph(
                size: glyphSize,
                arcReveal: arcReveal,
                batteryLevel: batteryLevel,
                networkReveal: networkReveal,
                dotReveals: initialDots,
                dotActivity: dotActivity,
                center: centerState,
                transition: centerTransition,
                intensity: 0.20 + 0.80 * Timing.progress(time, 0.62, 2.35, Timing.resolve)
            )
            .position(glyphPosition)

            unificationType
            brandType

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.25)],
                center: .center,
                startRadius: 410,
                endRadius: 1_180
            )
            .allowsHitTesting(false)
        }
        .frame(width: 1_920, height: 1_080)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var unificationType: some View {
        let lineIn = Timing.progress(time, 7.10, 0.62, Timing.type)
        let lineOut = Timing.progress(time, 8.38, 0.46, Timing.resolve)
        let oneIn = Timing.progress(time, 8.76, 0.40, Timing.type)
        let oneOut = Timing.progress(time, 9.28, 0.34, Timing.resolve)

        Text("Battery.  Network.  Volume.")
            .font(.system(size: 27, weight: .medium))
            .tracking(0.55)
            .foregroundStyle(Color.white.opacity(0.50 * lineIn * (1 - lineOut)))
            .position(x: 960, y: 785)
            .offset(y: 7 * CGFloat(1 - lineIn))

        Text("One.")
            .font(.system(size: 31, weight: .semibold))
            .tracking(0.2)
            .foregroundStyle(Color.white.opacity(0.80 * oneIn * (1 - oneOut)))
            .position(x: 960, y: 785)
            .scaleEffect(0.98 + 0.02 * oneIn)
    }

    @ViewBuilder
    private var brandType: some View {
        let title = Timing.progress(time, 17.625, 0.72, Timing.type)
        let idea = Timing.progress(time, 18.00, 0.76, Timing.type)
        let open = Timing.progress(time, 18.48, 0.66, Timing.type)
        let url = Timing.progress(time, 18.78, 0.66, Timing.type)

        VStack(alignment: .leading, spacing: 0) {
            Text("DuoBar 1.0")
                .font(.system(size: 68, weight: .semibold))
                .tracking(-0.9)
                .foregroundStyle(Color.white.opacity(0.95 * title))
                .offset(x: 12 * (1 - title))

            Text("Battery. Network. Volume.")
                .font(.system(size: 25, weight: .medium))
                .tracking(0.25)
                .foregroundStyle(Color.white.opacity(0.61 * idea))
                .padding(.top, 26)

            Text("One compact menu bar indicator.")
                .font(.system(size: 25, weight: .regular))
                .tracking(0.1)
                .foregroundStyle(Color.white.opacity(0.46 * idea))
                .padding(.top, 8)

            Text("Free & Open Source")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.68 * open))
                .padding(.top, 35)

            Text("github.com/Mikeli7666/DuoBar")
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.40 * url))
                .padding(.top, 11)
        }
        .frame(width: 610, alignment: .leading)
        .position(x: 1_320, y: 555)
        .opacity(brandProgress)
    }
}

private struct PosterFrame: View {
    var body: some View {
        ZStack {
            Color(red: 0.010, green: 0.014, blue: 0.020)
            RadialGradient(
                colors: [Color.white.opacity(0.026), Color.clear],
                center: UnitPoint(x: 0.34, y: 0.5),
                startRadius: 0,
                endRadius: 720
            )
            CinematicGlyph(
                size: 390,
                arcReveal: 1,
                batteryLevel: 0.92,
                networkReveal: 1,
                dotReveals: [1, 1, 1, 1],
                dotActivity: [1, 1, 1, 1],
                center: .wifi,
                transition: nil,
                intensity: 1
            )
            .position(x: 640, y: 530)

            VStack(alignment: .leading, spacing: 0) {
                Text("DuoBar 1.0")
                    .font(.system(size: 70, weight: .semibold))
                    .tracking(-1)
                    .foregroundStyle(Color.white.opacity(0.95))
                Text("Battery. Network. Volume.")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.59))
                    .padding(.top, 28)
                Text("One compact menu bar indicator.")
                    .font(.system(size: 25, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .padding(.top, 8)
                Text("Free & Open Source")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .padding(.top, 34)
                Text("github.com/Mikeli7666/DuoBar")
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.38))
                    .padding(.top, 10)
            }
            .frame(width: 610, alignment: .leading)
            .position(x: 1_320, y: 535)
        }
        .frame(width: 1_920, height: 1_080)
        .environment(\.colorScheme, .dark)
    }
}

private struct ContactSheet: View {
    let samples: [(String, CGImage)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("DuoBar 1.0 — Launch Film")
                    .font(.system(size: 30, weight: .semibold))
                Spacer()
                Text("Mystery → Formation → Unification → Intelligence → Context → Brand")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.42))
            }

            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 18) {
                    ForEach(0..<4, id: \.self) { column in
                        cell(samples[row * 4 + column])
                    }
                }
            }
        }
        .padding(38)
        .frame(width: 1_920, height: 970, alignment: .topLeading)
        .background(Color(red: 0.018, green: 0.023, blue: 0.031))
        .environment(\.colorScheme, .dark)
    }

    private func cell(_ sample: (String, CGImage)) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(decorative: sample.1, scale: 1)
                .resizable()
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(width: 447, height: 251)
                .overlay { Rectangle().stroke(Color.white.opacity(0.09), lineWidth: 1) }
            Text(sample.0)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.52))
        }
    }
}

@main
private struct RenderLaunchFilm {
    @MainActor
    static func main() async throws {
        try FileManager.default.createDirectory(at: Film.finalDirectory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: Film.visualMasterURL)

        let writer = try AVAssetWriter(outputURL: Film.visualMasterURL, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Film.width,
                AVVideoHeightKey: Film.height,
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
                ],
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 32_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: 120,
                    AVVideoAllowFrameReorderingKey: true,
                ],
            ]
        )
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Film.width,
                kCVPixelBufferHeightKey as String: Film.height,
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            ]
        )
        guard writer.canAdd(input) else { throw RenderError.cannotAddWriterInput }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? RenderError.writerFailed }
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<Film.frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            let time = Double(frame) / Double(Film.fps)
            let image = try render(view: LaunchFrame(time: time))
            let buffer = try makePixelBuffer(from: image, pool: adaptor.pixelBufferPool)
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: Film.fps)) else {
                throw writer.error ?? RenderError.appendFailed(frame)
            }
            if frame % 120 == 0 { print("Rendered frame \(frame)/\(Film.frameCount)") }
        }

        input.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }
        guard writer.status == .completed else { throw writer.error ?? RenderError.writerFailed }

        let poster = try render(view: PosterFrame())
        try writePNG(poster, to: Film.posterURL)

        let sampleTimes: [(String, Double)] = [
            ("0.75 · Mystery", 0.75),
            ("2.25 · Arc", 2.25),
            ("3.75 · Network", 3.75),
            ("4.875 · Formation", 4.875),
            ("6.0 · Unified", 6.0),
            ("7.875 · Volume", 7.875),
            ("9.98 · Ethernet", 9.98),
            ("11.1 · Wi-Fi", 11.10),
            ("12.3 · AirPods Pro", 12.30),
            ("15.0 · Context pull-back", 15.0),
            ("15.75 · Menu bar", 15.75),
            ("19.2 · Brand", 19.2),
        ]
        let asset = AVURLAsset(url: Film.visualMasterURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        var samples: [(String, CGImage)] = []
        for sample in sampleTimes {
            let image = try await decodedFrame(from: generator, at: CMTime(seconds: sample.1, preferredTimescale: 600))
            samples.append((sample.0, image))
        }
        let sheet = try render(view: ContactSheet(samples: samples))
        try writePNG(sheet, to: Film.contactSheetURL)

        print("Visual master: \(Film.visualMasterURL.path)")
        print("Contact sheet: \(Film.contactSheetURL.path)")
        print("Poster: \(Film.posterURL.path)")
    }

    @MainActor
    private static func render<V: View>(view: V) throws -> CGImage {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.cgImage else { throw RenderError.renderFailed }
        return image
    }

    private static func makePixelBuffer(from image: CGImage, pool: CVPixelBufferPool?) throws -> CVPixelBuffer {
        var optionalBuffer: CVPixelBuffer?
        let status: CVReturn
        if let pool {
            status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer)
        } else {
            status = CVPixelBufferCreate(
                nil, Film.width, Film.height, kCVPixelFormatType_32BGRA,
                [
                    kCVPixelBufferCGImageCompatibilityKey: true,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                ] as CFDictionary,
                &optionalBuffer
            )
        }
        guard status == kCVReturnSuccess, let buffer = optionalBuffer else {
            throw RenderError.pixelBufferFailed(status)
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Film.width,
            height: Film.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { throw RenderError.contextFailed }
        context.draw(image, in: CGRect(x: 0, y: 0, width: Film.width, height: Film.height))
        return buffer
    }

    private static func decodedFrame(from generator: AVAssetImageGenerator, at time: CMTime) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { image, _, error in
                if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: error ?? RenderError.renderFailed) }
            }
        }
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw RenderError.pngFailed
        }
        try data.write(to: url, options: .atomic)
    }
}

private enum RenderError: LocalizedError {
    case cannotAddWriterInput
    case writerFailed
    case appendFailed(Int)
    case renderFailed
    case pixelBufferFailed(CVReturn)
    case contextFailed
    case pngFailed

    var errorDescription: String? {
        switch self {
        case .cannotAddWriterInput: "Unable to add the video writer input."
        case .writerFailed: "The video writer did not complete."
        case .appendFailed(let frame): "Unable to append frame \(frame)."
        case .renderFailed: "Unable to render a deterministic frame."
        case .pixelBufferFailed(let status): "Unable to allocate a pixel buffer (\(status))."
        case .contextFailed: "Unable to create a Core Graphics context."
        case .pngFailed: "Unable to encode PNG."
        }
    }
}
