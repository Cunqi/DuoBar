import AppKit
import AVFoundation
import CoreGraphics
import SwiftUI

private enum Film {
    static let width = 1_920
    static let height = 1_080
    static let framesPerSecond: Int32 = 60
    static let duration = 7.2
    static let frameCount = Int(duration * Double(framesPerSecond))

    static let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("marketing/1.0/launch-film/concept", isDirectory: true)
    static let videoURL = outputDirectory.appendingPathComponent("DuoBar-1.0-concept-proof.mp4")
    static let contactSheetURL = outputDirectory.appendingPathComponent("DuoBar-1.0-concept-contact-sheet.png")
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

        for _ in 0..<16 {
            let x = component(parameter, a: x1, b: x2)
            if abs(x - target) < 0.000_01 { break }
            if x < target {
                lower = parameter
            } else {
                upper = parameter
            }
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
    static let arc = CubicBezier(x1: 0.55, y1: 0.0, x2: 0.34, y2: 1.0)
    static let camera = CubicBezier(x1: 0.32, y1: 0.0, x2: 0.20, y2: 1.0)
    static let network = CubicBezier(x1: 0.24, y1: 0.0, x2: 0.25, y2: 1.0)
    static let dot = CubicBezier(x1: 0.18, y1: 0.0, x2: 0.24, y2: 1.0)
    static let type = CubicBezier(x1: 0.22, y1: 0.0, x2: 0.24, y2: 1.0)

    static func progress(_ time: Double, from start: Double, duration: Double, curve: CubicBezier) -> Double {
        curve.value(at: (time - start) / duration)
    }
}

private struct ProductionArc: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        let amount = min(max(progress, 0), 1)
        guard amount > 0 else { return Path() }

        // Exact production geometry from DuoGlyphMetrics.standard:
        // 110° gap, anchored at 145°, ending at 395°.
        let startDegrees = 145.0
        let endDegrees = 395.0
        let visibleEnd = startDegrees + (endDegrees - startDegrees) * amount
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.5
        let samples = 180

        var path = Path()
        for index in 0...samples {
            let unit = Double(index) / Double(samples)
            let degrees = startDegrees + (visibleEnd - startDegrees) * unit
            let radians = degrees * .pi / 180
            let point = CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }
}

private struct ArcHead: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        let end = min(max(progress, 0), 1)
        let start = max(0, end - 0.055)
        guard end > 0, end < 0.995 else { return Path() }

        let startDegrees = 145.0 + 250.0 * start
        let endDegrees = 145.0 + 250.0 * end
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.5
        var path = Path()
        for index in 0...24 {
            let unit = Double(index) / 24.0
            let radians = (startDegrees + (endDegrees - startDegrees) * unit) * .pi / 180
            let point = CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }
}

private struct CinematicDuoGlyph: View {
    let size: CGFloat
    let arcProgress: Double
    let arcIntensity: Double
    let networkProgress: Double
    let dotProgress: [Double]

    private var ringDiameter: CGFloat { size * (19.875 / 24.0) }
    private var ringLineWidth: CGFloat { size * (2.1 / 24.0) }
    private var ringYOffset: CGFloat { size * (-0.6 / 24.0) }
    private var wifiSize: CGFloat { size * (9.3 / 24.0) }
    private var wifiYOffset: CGFloat { size * (-0.9375 / 24.0) }
    private var wifiFrameWidth: CGFloat { size * (15.345 / 24.0) }
    private var wifiFrameHeight: CGFloat { size * (13.02 / 24.0) }
    private var dotDiameter: CGFloat { size * (2.175 / 24.0) }
    private var dotSpacing: CGFloat { size * (1.35 / 24.0) }
    private var dotYOffset: CGFloat { size * (8.4 / 24.0) }

    var body: some View {
        ZStack {
            ProductionArc(progress: 1)
                .stroke(
                    Color.white.opacity(0.009),
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round, lineJoin: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .offset(y: ringYOffset)

            ProductionArc(progress: arcProgress)
                .stroke(
                    Color.white.opacity(0.93 * arcIntensity),
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round, lineJoin: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .offset(y: ringYOffset)

            ArcHead(progress: arcProgress)
                .stroke(
                    Color.white.opacity(0.16 * arcIntensity * (1 - min(max((arcProgress - 0.86) / 0.14, 0), 1))),
                    style: StrokeStyle(lineWidth: ringLineWidth * 1.045, lineCap: .round, lineJoin: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .offset(y: ringYOffset)

            if networkProgress > 0.001 {
                Image(systemName: "wifi", variableValue: 1)
                    .font(.system(size: wifiSize, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.white.opacity(0.94))
                    .frame(width: wifiFrameWidth, height: wifiFrameHeight)
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(width: wifiFrameWidth, height: max(1, wifiFrameHeight * networkProgress))
                            .blur(radius: max(0.5, wifiFrameHeight * 0.012))
                    }
                    .scaleEffect(0.975 + 0.025 * networkProgress)
                    .offset(y: wifiYOffset + size * 0.018 * (1 - networkProgress))
            }

            HStack(spacing: dotSpacing) {
                ForEach(0..<4, id: \.self) { index in
                    let reveal = dotProgress[index]
                    Circle()
                        .fill(Color.white.opacity(0.92 * reveal))
                        .frame(width: dotDiameter, height: dotDiameter)
                        .scaleEffect(0.72 + 0.28 * reveal)
                        .offset(y: size * 0.022 * (1 - reveal))
                }
            }
            .offset(y: dotYOffset)
        }
        .frame(width: size, height: size)
    }
}

private struct ConceptFrame: View {
    let time: Double

    private var cameraProgress: Double {
        Timing.progress(time, from: 0.15, duration: 5.35, curve: Timing.camera)
    }

    private var arcProgress: Double {
        Timing.progress(time, from: 0.28, duration: 3.18, curve: Timing.arc)
    }

    private var networkProgress: Double {
        Timing.progress(time, from: 1.58, duration: 1.72, curve: Timing.network)
    }

    private var arcIntensity: Double {
        0.18 + 0.82 * Timing.progress(time, from: 0.28, duration: 2.35, curve: Timing.type)
    }

    private var dots: [Double] {
        [3.12, 3.34, 3.59, 3.87].map {
            Timing.progress(time, from: $0, duration: 0.56, curve: Timing.dot)
        }
    }

    private var titleProgress: Double {
        Timing.progress(time, from: 5.08, duration: 0.92, curve: Timing.type)
    }

    private var subtitleProgress: Double {
        Timing.progress(time, from: 5.34, duration: 1.0, curve: Timing.type)
    }

    private var objectSize: CGFloat {
        CGFloat(2_100 - 1_660 * cameraProgress)
    }

    private var objectX: CGFloat {
        let pan = Timing.progress(time, from: 0.32, duration: 5.0, curve: Timing.camera)
        return CGFloat(1_100 - 380 * pan)
    }

    private var objectY: CGFloat {
        let settle = Timing.progress(time, from: 0.0, duration: 4.8, curve: Timing.camera)
        return CGFloat(500 + 30 * settle)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.010, green: 0.014, blue: 0.020)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.024),
                    Color(red: 0.03, green: 0.045, blue: 0.063).opacity(0.018),
                    Color.clear
                ],
                center: UnitPoint(x: objectX / 1_920, y: objectY / 1_080),
                startRadius: 0,
                endRadius: 760
            )

            CinematicDuoGlyph(
                size: objectSize,
                arcProgress: arcProgress,
                arcIntensity: arcIntensity,
                networkProgress: networkProgress,
                dotProgress: dots
            )
            .position(x: objectX, y: objectY)

            VStack(alignment: .leading, spacing: 18) {
                Text("DuoBar 1.0")
                    .font(.system(size: 58, weight: .semibold, design: .default))
                    .tracking(-0.8)
                    .foregroundStyle(Color.white.opacity(0.94))
                    .frame(width: 520, alignment: .leading)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: max(1, 520 * titleProgress))
                    }
                    .opacity(min(1, titleProgress * 1.5))
                    .offset(x: 10 * (1 - titleProgress))

                Text("Three essentials. One indicator.")
                    .font(.system(size: 25, weight: .regular, design: .default))
                    .tracking(0.15)
                    .foregroundStyle(Color.white.opacity(0.48 * subtitleProgress))
                    .frame(width: 560, alignment: .leading)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: max(1, 560 * subtitleProgress))
                    }
                    .offset(x: 8 * (1 - subtitleProgress))
            }
            .position(x: 1_385, y: 520)

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.24)],
                center: .center,
                startRadius: 420,
                endRadius: 1_180
            )
            .allowsHitTesting(false)
        }
        .frame(width: 1_920, height: 1_080)
        .clipped()
        .environment(\.colorScheme, .dark)
    }
}

private struct ContactSheet: View {
    let samples: [(String, CGImage)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                Text("DuoBar 1.0 — Concept Proof")
                    .font(.system(size: 28, weight: .semibold))
                Spacer()
                Text("Cinematic progression")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.white.opacity(0.46))
            }

            VStack(spacing: 24) {
                HStack(spacing: 24) {
                    ForEach(0..<3, id: \.self) { index in
                        cell(samples[index])
                    }
                }
                HStack(spacing: 24) {
                    ForEach(3..<6, id: \.self) { index in
                        cell(samples[index])
                    }
                }
            }
        }
        .padding(36)
        .frame(width: 1_824, height: 850, alignment: .topLeading)
        .background(Color(red: 0.018, green: 0.023, blue: 0.031))
        .environment(\.colorScheme, .dark)
    }

    private func cell(_ sample: (String, CGImage)) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(decorative: sample.1, scale: 1)
                .resizable()
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(width: 560, height: 315)
                .overlay {
                    Rectangle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
            Text(sample.0)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
        }
    }
}

@main
private struct RenderConceptProof {
    @MainActor
    static func main() async throws {
        try FileManager.default.createDirectory(at: Film.outputDirectory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: Film.videoURL)

        let writer = try AVAssetWriter(outputURL: Film.videoURL, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Film.width,
                AVVideoHeightKey: Film.height,
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
                ],
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 28_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: 120,
                    AVVideoAllowFrameReorderingKey: true
                ]
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
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
        )

        guard writer.canAdd(input) else { throw RenderError.cannotAddWriterInput }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? RenderError.writerFailed }
        writer.startSession(atSourceTime: .zero)

        for frameIndex in 0..<Film.frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }

            let time = Double(frameIndex) / Double(Film.framesPerSecond)
            let image = try renderFrame(at: time)
            let buffer = try makePixelBuffer(from: image, pool: adaptor.pixelBufferPool)
            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: Film.framesPerSecond)
            guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? RenderError.appendFailed(frameIndex)
            }

            if frameIndex % 60 == 0 {
                print("Rendered frame \(frameIndex)/\(Film.frameCount)")
            }
        }

        input.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting {
                continuation.resume()
            }
        }
        guard writer.status == .completed else { throw writer.error ?? RenderError.writerFailed }

        let sampleTimes: [(String, Double)] = [
            ("0.5 s", 0.5),
            ("1.5 s", 1.5),
            ("2.5 s", 2.5),
            ("3.5 s", 3.5),
            ("5.0 s", 5.0),
            ("Final", 7.15)
        ]
        let encodedAsset = AVURLAsset(url: Film.videoURL)
        let frameGenerator = AVAssetImageGenerator(asset: encodedAsset)
        frameGenerator.appliesPreferredTrackTransform = true
        frameGenerator.requestedTimeToleranceBefore = .zero
        frameGenerator.requestedTimeToleranceAfter = .zero
        var samples: [(String, CGImage)] = []
        for (label, time) in sampleTimes {
            let image = try await decodedFrame(
                from: frameGenerator,
                at: CMTime(seconds: time, preferredTimescale: 600)
            )
            samples.append((label, image))
        }
        let contactRenderer = ImageRenderer(content: ContactSheet(samples: samples))
        contactRenderer.scale = 1
        guard let contactImage = contactRenderer.cgImage else { throw RenderError.renderFailed }
        try writePNG(contactImage, to: Film.contactSheetURL)

        print("Video: \(Film.videoURL.path)")
        print("Contact sheet: \(Film.contactSheetURL.path)")
    }

    @MainActor
    private static func renderFrame(at time: Double) throws -> CGImage {
        let renderer = ImageRenderer(content: ConceptFrame(time: time))
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
                nil,
                Film.width,
                Film.height,
                kCVPixelFormatType_32BGRA,
                [
                    kCVPixelBufferCGImageCompatibilityKey: true,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: true
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
        ) else {
            throw RenderError.contextFailed
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: Film.width, height: Film.height))
        return buffer
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw RenderError.pngFailed
        }
        try data.write(to: url, options: .atomic)
    }

    private static func decodedFrame(
        from generator: AVAssetImageGenerator,
        at time: CMTime
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { image, _, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? RenderError.renderFailed)
                }
            }
        }
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
        case .pngFailed: "Unable to encode the contact sheet."
        }
    }
}
