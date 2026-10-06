import DuoBarCore
import SwiftUI

struct PopoverSettingsPane: View {
    let hasBattery: Bool

    @AppStorage(PreferenceKeys.popoverLayout) private var popoverLayoutRaw = ""
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("Choose what the popover shows. Drag to reorder."))
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(layout.configurableEntries(hasBattery: hasBattery)) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                        Image(systemName: entry.module.symbol)
                            .frame(width: 18)
                            .foregroundStyle(.secondary)
                        Text(entry.module.localizedDisplayName)
                        Spacer()
                        Toggle(entry.module.localizedDisplayName, isOn: visibility(of: entry.module))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                    .padding(.vertical, 3)
                }
                .onMove { source, destination in
                    var updated = layout
                    updated.moveConfigurable(fromOffsets: source, toOffset: destination, hasBattery: hasBattery)
                    popoverLayoutRaw = updated.storageValue
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .frame(height: CGFloat(layout.configurableEntries(hasBattery: hasBattery).count) * 34 + 12)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if hasBattery {
                Toggle(localized("Show battery percentage in popover"), isOn: $showBatteryPercentage)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var layout: PopoverLayout {
        PopoverLayout.resolve(stored: popoverLayoutRaw, hasBattery: hasBattery)
    }

    private func visibility(of module: PopoverModule) -> Binding<Bool> {
        Binding(
            get: { layout.entries.first { $0.module == module }?.isVisible ?? true },
            set: { isVisible in
                var updated = layout
                updated.setVisible(isVisible, for: module)
                popoverLayoutRaw = updated.storageValue
            }
        )
    }
}
