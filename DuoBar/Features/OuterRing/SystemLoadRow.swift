import DuoBarCore
import SwiftUI

struct SystemLoadRow: View {
    @ObservedObject private var monitor = AdaptiveRingMonitor.shared
    @State private var owner = UUID()

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "cpu")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 0) {
                metric(localized("CPU"), value: cpuText)
                metric(localized("Memory"), value: memoryText)
                metric(localized("Thermal"), value: thermalText)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onAppear { monitor.acquire(owner: owner) }
        .onDisappear { monitor.release(owner: owner) }
        .accessibilityElement(children: .combine)
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cpuText: String {
        guard let load = monitor.performanceSnapshot?.cpuLoad else { return "–" }
        return localized("%d%%", Int((load * 100).rounded()))
    }

    private var memoryText: String {
        guard let memory = monitor.performanceSnapshot?.memory else { return "–" }
        return localized("%d%%", Int(((1 - memory.availableHeadroom) * 100).rounded()))
    }

    private var thermalText: String {
        guard let snapshot = monitor.performanceSnapshot else { return "–" }
        return RingReading.thermalLabel(for: snapshot.thermalState)
    }
}
