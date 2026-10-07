import Foundation

public struct DiskSpaceStatus: Equatable, Sendable {
    public init(
        totalBytes: Int64,
        availableBytes: Int64
    ) {
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
    }

    public var totalBytes: Int64
    public var availableBytes: Int64

    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(totalBytes - availableBytes) / Double(totalBytes), 0), 1)
    }

    public var usedPercentage: Int {
        Int((usedFraction * 100).rounded())
    }
}
