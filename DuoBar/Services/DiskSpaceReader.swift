import Foundation

enum DiskSpaceReader {
    static func startupVolume() -> DiskSpaceStatus? {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return DiskSpaceStatus(totalBytes: Int64(total), availableBytes: available)
    }
}
