import CoreAudio
import Foundation

enum AudioDeviceDirection: Sendable {
    case output
    case input
}

struct AudioDeviceDescriptor: Equatable, Sendable {
    var id: AudioDeviceID
    var name: String
    var hasOutput: Bool
    var hasInput: Bool
}

struct AudioDeviceOption: Identifiable, Equatable, Sendable {
    var id: AudioDeviceID
    var name: String
    var isDefault: Bool

    static func options(
        from descriptors: [AudioDeviceDescriptor],
        direction: AudioDeviceDirection,
        defaultID: AudioDeviceID?
    ) -> [AudioDeviceOption] {
        descriptors
            .filter { direction == .output ? $0.hasOutput : $0.hasInput }
            .map { AudioDeviceOption(id: $0.id, name: $0.name, isDefault: $0.id == defaultID) }
    }
}

struct DiskSpaceStatus: Equatable, Sendable {
    var totalBytes: Int64
    var availableBytes: Int64

    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(totalBytes - availableBytes) / Double(totalBytes), 0), 1)
    }

    var usedPercentage: Int {
        Int((usedFraction * 100).rounded())
    }
}
