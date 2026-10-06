import Foundation

public enum PerformanceThermalState: Int, CaseIterable, Comparable, Sendable {
    case nominal
    case fair
    case serious
    case critical

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum MemoryStressEstimate: Int, CaseIterable, Comparable, Sendable {
    case normal
    case elevated
    case serious
    case critical

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct MemorySnapshot: Equatable, Sendable {
    public init(
        totalBytes: UInt64,
        availableBytes: UInt64,
        compressedBytes: UInt64,
        pageOutsPerSecond: Double,
        stress: MemoryStressEstimate
    ) {
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.compressedBytes = compressedBytes
        self.pageOutsPerSecond = pageOutsPerSecond
        self.stress = stress
    }

    public var totalBytes: UInt64
    public var availableBytes: UInt64
    public var compressedBytes: UInt64
    public var pageOutsPerSecond: Double
    public var stress: MemoryStressEstimate

    public var availableHeadroom: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(availableBytes) / Double(totalBytes), 0), 1)
    }

    public var compressionRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(compressedBytes) / Double(totalBytes), 0), 1)
    }
}

public struct PerformanceSnapshot: Equatable, Sendable {
    public init(
        timestamp: TimeInterval,
        cpuLoad: Double?,
        memory: MemorySnapshot?,
        thermalState: PerformanceThermalState
    ) {
        self.timestamp = timestamp
        self.cpuLoad = cpuLoad
        self.memory = memory
        self.thermalState = thermalState
    }

    public var timestamp: TimeInterval
    public var cpuLoad: Double?
    public var memory: MemorySnapshot?
    public var thermalState: PerformanceThermalState

    // No public API provides system-wide GPU utilization to a normal macOS app.
    public var gpuLoad: Double? { nil }
}
