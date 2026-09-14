import AVFoundation
import Foundation

private enum Paths {
    static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("marketing/1.0/launch-film", isDirectory: true)
    static let video = root.appendingPathComponent("final/.DuoBar-1.0-Official-visual-master.mp4")
    static let audio = root.appendingPathComponent("audio/DuoBar-1.0-final-mix.wav")
    static let output = root.appendingPathComponent("final/DuoBar-1.0-Official-Launch-Film.mp4")
}

@main
private struct MuxLaunchFilm {
    static func main() async throws {
        let videoAsset = AVURLAsset(url: Paths.video)
        let audioAsset = AVURLAsset(url: Paths.audio)
        let videoDuration = try await videoAsset.load(.duration)
        let composition = AVMutableComposition()

        guard
            let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first,
            let destinationVideo = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else { throw MuxError.missingVideo }

        try destinationVideo.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: sourceVideo,
            at: .zero
        )
        destinationVideo.preferredTransform = try await sourceVideo.load(.preferredTransform)

        guard
            let sourceAudio = try await audioAsset.loadTracks(withMediaType: .audio).first,
            let destinationAudio = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else { throw MuxError.missingAudio }

        try destinationAudio.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: sourceAudio,
            at: .zero
        )

        try? FileManager.default.removeItem(at: Paths.output)
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw MuxError.cannotCreateExporter
        }
        try await exporter.export(to: Paths.output, as: .mp4)
        print("Final master: \(Paths.output.path)")
    }
}

private enum MuxError: LocalizedError {
    case missingVideo
    case missingAudio
    case cannotCreateExporter

    var errorDescription: String? {
        switch self {
        case .missingVideo: "The visual master has no video track."
        case .missingAudio: "The final mix has no audio track."
        case .cannotCreateExporter: "Unable to create AVFoundation exporter."
        }
    }
}
