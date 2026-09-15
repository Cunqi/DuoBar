import Foundation

@main
struct PerformanceRingDiagnostic {
    static func main() {
        let context = DeviceContextService().current()
        let sampler = PerformanceTelemetrySampler()
        _ = sampler.sample()
        Thread.sleep(forTimeInterval: 0.25)

        print("device.hasInternalBattery=\(context.hasInternalBattery)")
        print("device.behavior=\(context.performanceBehavior.rawValue)")
        printSamples(label: "idle", sampler: sampler, count: 6, interval: 0.5)

        if CommandLine.arguments.contains("--idle-only") {
            measureSamplingLatency(sampler)
            return
        }

        let cpuGroup = DispatchGroup()
        let workerCount = min(max(ProcessInfo.processInfo.activeProcessorCount, 1), 8)
        let end = Date().addingTimeInterval(3)
        for seed in 0..<workerCount {
            cpuGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                var accumulator = UInt64(seed + 1)
                while Date() < end {
                    accumulator = accumulator &* 2_862_933_555_777_941_757 &+ 3_037_000_493
                }
                withExtendedLifetime(accumulator) {}
                cpuGroup.leave()
            }
        }
        printSamples(label: "cpu-workload", sampler: sampler, count: 6, interval: 0.5)
        cpuGroup.wait()

        var memory = [UInt8](repeating: 0, count: 256 * 1_024 * 1_024)
        var checksum: UInt64 = 0
        for index in stride(from: 0, to: memory.count, by: 4_096) {
            memory[index] = UInt8(truncatingIfNeeded: index / 4_096)
            checksum &+= UInt64(memory[index])
        }
        printSamples(label: "memory-activity", sampler: sampler, count: 4, interval: 0.5)
        print("memory.checksum=\(checksum)")
        withExtendedLifetime(memory) {}

        measureSamplingLatency(sampler)
        print("gpu.systemWide=unavailable-public-api")
    }

    private static func measureSamplingLatency(_ sampler: PerformanceTelemetrySampler) {
        var latencies = [Double]()
        latencies.reserveCapacity(500)
        for _ in 0..<500 {
            let start = ContinuousClock.now
            _ = sampler.sample()
            let duration = ContinuousClock.now - start
            latencies.append(duration.seconds * 1_000_000)
        }
        latencies.sort()
        let mean = latencies.reduce(0, +) / Double(latencies.count)
        let median = latencies[latencies.count / 2]
        let p95 = latencies[Int(Double(latencies.count - 1) * 0.95)]
        print(String(format: "sampling.latency_us mean=%.1f median=%.1f p95=%.1f", mean, median, p95))
    }

    private static func printSamples(
        label: String,
        sampler: PerformanceTelemetrySampler,
        count: Int,
        interval: TimeInterval
    ) {
        for index in 1...count {
            Thread.sleep(forTimeInterval: interval)
            let snapshot = sampler.sample()
            let cpu = snapshot.cpuLoad.map { String(format: "%.1f%%", $0 * 100) } ?? "unavailable"
            let memory = snapshot.memory
            let headroom = memory.map { String(format: "%.1f%%", $0.availableHeadroom * 100) } ?? "unavailable"
            let compression = memory.map { String(format: "%.1f%%", $0.compressionRatio * 100) } ?? "unavailable"
            let pageOuts = memory.map { String(format: "%.2f/s", $0.pageOutsPerSecond) } ?? "unavailable"
            let stress = memory.map { String(describing: $0.stress) } ?? "unavailable"
            print(
                "\(label)[\(index)] cpu=\(cpu) memoryHeadroom=\(headroom) "
                + "compressed=\(compression) pageOuts=\(pageOuts) memoryEstimate=\(stress) "
                + "thermal=\(snapshot.thermalState)"
            )
        }
    }
}

private extension Duration {
    var seconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
