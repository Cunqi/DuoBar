#if DEBUG
import SwiftUI

struct DebugPerformanceDiagnosticsView: View {
    @AppStorage(PreferenceKeys.simulateDesktopMac) private var simulateDesktopMac = false
    @StateObject private var monitor = PerformancePrototypeMonitor()
    private let deviceContextService = DeviceContextService()

    private var context: DeviceContext {
        deviceContextService.current(simulateDesktop: simulateDesktopMac)
    }

    var body: some View {
        Section("Performance Ring · Debug") {
            Toggle("Simulate Desktop Mac", isOn: $simulateDesktopMac)

            LabeledContent("Behavior", value: context.performanceBehavior.rawValue)
            LabeledContent("Internal battery", value: context.hasInternalBattery ? "Detected" : "Not detected")
            LabeledContent("CPU", value: percent(monitor.snapshot?.cpuLoad))
            LabeledContent("Memory headroom", value: percent(monitor.snapshot?.memory?.availableHeadroom))
            LabeledContent("Memory estimate", value: memoryLabel)
            LabeledContent("Thermal", value: thermalLabel)
            LabeledContent("Candidate", value: monitor.decision.candidate.metric.rawValue)
            LabeledContent("Active", value: monitor.decision.activeMetric.rawValue)
            Text(monitor.decision.reason.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private var memoryLabel: String {
        guard let stress = monitor.snapshot?.memory?.stress else { return "Unavailable" }
        return String(describing: stress).capitalized
    }

    private var thermalLabel: String {
        guard let thermal = monitor.snapshot?.thermalState else { return "Unavailable" }
        return String(describing: thermal).capitalized
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "Sampling…" }
        return value.formatted(.percent.precision(.fractionLength(1)))
    }
}
#endif
