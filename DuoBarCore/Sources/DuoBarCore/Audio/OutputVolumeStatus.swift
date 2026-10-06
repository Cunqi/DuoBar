import Foundation

public struct OutputVolumeStatus: Equatable, Sendable {
    public var level: Double?
    public var isMuted: Bool
    public var isSettable: Bool
    public var isMuteSettable: Bool

    public init(level: Double?, isMuted: Bool, isSettable: Bool, isMuteSettable: Bool = false) {
        self.level = level
        self.isMuted = isMuted
        self.isSettable = isSettable
        self.isMuteSettable = isMuteSettable
    }

    public static let unavailable = OutputVolumeStatus(
        level: nil,
        isMuted: false,
        isSettable: false,
        isMuteSettable: false
    )

    public var percentage: Int? {
        level.map { min(max(Int(($0 * 100).rounded()), 0), 100) }
    }

    public var activeDotCount: Int? {
        guard let percentage else { return nil }
        if isMuted || percentage == 0 { return 0 }

        switch percentage {
        case 1...25: return 1
        case 26...50: return 2
        case 51...75: return 3
        default: return 4
        }
    }
}
