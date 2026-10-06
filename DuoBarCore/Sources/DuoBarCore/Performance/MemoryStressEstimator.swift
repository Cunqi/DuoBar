public struct MemoryStressEstimator {
    public static func estimate(headroom: Double, compression: Double, pageOutsPerSecond: Double) -> MemoryStressEstimate {
        if headroom <= 0.03, pageOutsPerSecond >= 64 {
            return .critical
        }
        if headroom <= 0.06, pageOutsPerSecond >= 8 || compression >= 0.45 {
            return .serious
        }
        if headroom <= 0.03 {
            return .elevated
        }
        if headroom <= 0.10, pageOutsPerSecond > 0 || compression >= 0.30 {
            return .elevated
        }
        return .normal
    }
}
