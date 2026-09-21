import SwiftUI

struct PopoverCard<Header: View, Expanded: View>: View {
    let canExpand: Bool
    @ViewBuilder let header: Header
    @ViewBuilder let expanded: Expanded

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                header
                if canExpand {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
            .onTapGesture {
                guard canExpand else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded, canExpand {
                Divider()
                    .padding(.horizontal, 10)
                expanded
                    .padding(.vertical, 6)
            }
        }
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

struct PopoverCardHeader: View {
    let symbol: String
    let title: String
    let detail: String
    var stateText: String?

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let stateText {
                Text(stateText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
    }
}

struct AudioDeviceList: View {
    let options: [AudioDeviceOption]
    let onSelect: (AudioDeviceOption) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(options) { option in
                AudioDeviceListRow(option: option) { onSelect(option) }
            }
        }
    }
}

private struct AudioDeviceListRow: View {
    let option: AudioDeviceOption
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(option.name)
                    .font(.system(size: 11.5, weight: option.isDefault ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if option.isDefault {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10.5, weight: .semibold))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    .padding(.horizontal, 4)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(option.isDefault ? .isSelected : [])
    }
}

struct AudioOutputSection: View {
    let symbol: String
    let detail: String
    let stateText: String
    @ObservedObject var switcher: AudioDeviceSwitcher

    var body: some View {
        PopoverCard(canExpand: switcher.outputs.count > 1) {
            PopoverCardHeader(symbol: symbol, title: localized("Audio Output"), detail: detail, stateText: stateText)
        } expanded: {
            AudioDeviceList(options: switcher.outputs) { switcher.setDefault($0, direction: .output) }
        }
    }
}

struct AudioInputSection: View {
    @ObservedObject var switcher: AudioDeviceSwitcher

    var body: some View {
        PopoverCard(canExpand: switcher.inputs.count > 1) {
            VStack(alignment: .leading, spacing: 4) {
                PopoverCardHeader(
                    symbol: symbol,
                    title: localized("Audio Input"),
                    detail: switcher.defaultInput?.name ?? localized("No input device")
                )
                if switcher.isInputVolumeSettable, let volume = switcher.inputVolume {
                    Slider(value: Binding(get: { volume }, set: switcher.setInputVolume), in: 0...1)
                        .controlSize(.mini)
                        .padding(.leading, 39)
                        .padding(.bottom, 6)
                        .accessibilityLabel(localized("Input volume"))
                }
            }
            .padding(.top, switcher.isInputVolumeSettable ? 6 : 0)
        } expanded: {
            AudioDeviceList(options: switcher.inputs) { switcher.setDefault($0, direction: .input) }
        }
    }

    private var symbol: String {
        guard let volume = switcher.inputVolume else { return "mic" }
        return volume <= 0.001 ? "mic.slash" : "mic"
    }
}

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

struct KeepAwakeRow: View {
    @ObservedObject private var service = KeepAwakeService.shared

    var body: some View {
        StatusRow(
            symbol: service.isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer",
            title: localized("Keep Awake"),
            detail: service.isEnabled ? localized("Display and system won't sleep automatically") : localized("Off"),
            stateText: "",
            tint: .primary,
            trailing: AnyView(
                Toggle(localized("Keep Awake"), isOn: Binding(get: { service.isEnabled }, set: service.setEnabled))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            )
        )
    }
}

struct DiskSpaceRow: View {
    @State private var disk = DiskSpaceReader.startupVolume()

    var body: some View {
        StatusRow(
            symbol: "internaldrive",
            title: localized("Disk Space"),
            detail: detail,
            stateText: disk.map { localized("%d%%", $0.usedPercentage) } ?? "",
            tint: .primary
        )
        .onAppear { disk = DiskSpaceReader.startupVolume() }
    }

    private var detail: String {
        guard let disk else { return localized("No data") }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return localized(
            "%@ available of %@",
            formatter.string(fromByteCount: disk.availableBytes),
            formatter.string(fromByteCount: disk.totalBytes)
        )
    }
}
