import AppKit
import AVFoundation
import SwiftUI

private struct TransitionSheet: View {
    let samples: [(String, CGImage)]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("DuoBar 1.0 — Encoded Transition QC")
                .font(.system(size: 28, weight: .semibold))
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { column in
                        let sample = samples[row * 5 + column]
                        VStack(alignment: .leading, spacing: 6) {
                            Image(decorative: sample.1, scale: 1)
                                .resizable()
                                .aspectRatio(16 / 9, contentMode: .fit)
                                .frame(width: 330, height: 186)
                                .overlay { Rectangle().stroke(Color.white.opacity(0.10), lineWidth: 1) }
                            Text(sample.0)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                    }
                }
            }
        }
        .padding(34)
        .frame(width: 1_746, height: 920, alignment: .topLeading)
        .background(Color(red: 0.018, green: 0.023, blue: 0.031))
        .environment(\.colorScheme, .dark)
    }
}

@main
private struct InspectLaunchTransitions {
    @MainActor
    static func main() async throws {
        let video = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("marketing/1.0/launch-film/final/DuoBar-1.0-Official-Launch-Film.mp4")
        let output = URL(fileURLWithPath: "/private/tmp/DuoBar-1.0-Official-transition-qc.png")
        let events: [(String, Int)] = [
            ("Wi-Fi → Ethernet", 585),
            ("Ethernet → Wi-Fi", 653),
            ("Wi-Fi → AirPods", 720),
            ("AirPods → Wi-Fi", 788),
        ]
        var moments: [(String, Double)] = []
        for event in events {
            for frameIndex in (event.1 + 18)...(event.1 + 22) {
                moments.append(("\(event.0) · f\(frameIndex)", Double(frameIndex) / 60.0))
            }
        }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        var samples: [(String, CGImage)] = []
        for moment in moments {
            let image = try await frame(
                from: generator,
                at: CMTime(seconds: moment.1, preferredTimescale: 600)
            )
            samples.append((moment.0, image))
        }

        for event in events {
            var previousHash: UInt64?
            var duplicateCount = 0
            for frameIndex in event.1...(event.1 + 40) {
                let image = try await frame(
                    from: generator,
                    at: CMTime(value: CMTimeValue(frameIndex), timescale: 60)
                )
                let currentHash = hash(image)
                if currentHash == previousHash { duplicateCount += 1 }
                previousHash = currentHash
            }
            print("\(event.0): activeFrames=41 unintendedAdjacentDuplicates=\(duplicateCount)")
        }
        let renderer = ImageRenderer(content: TransitionSheet(samples: samples))
        renderer.scale = 1
        guard let image = renderer.cgImage else { throw QCError.renderFailed }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw QCError.renderFailed }
        try data.write(to: output, options: .atomic)
        print(output.path)
    }

    private static func frame(from generator: AVAssetImageGenerator, at time: CMTime) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { image, _, error in
                if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: error ?? QCError.renderFailed) }
            }
        }
    }

    private static func hash(_ image: CGImage) -> UInt64 {
        guard let data = image.dataProvider?.data else { return 0 }
        let length = CFDataGetLength(data)
        guard let bytes = CFDataGetBytePtr(data) else { return 0 }
        var value: UInt64 = 14_695_981_039_346_656_037
        let stride = max(1, length / 65_536)
        var index = 0
        while index < length {
            value ^= UInt64(bytes[index])
            value &*= 1_099_511_628_211
            index += stride
        }
        return value
    }
}

private enum QCError: Error {
    case renderFailed
}
