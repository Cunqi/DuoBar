import DuoBarCore
import SwiftUI

struct MenuBarSettingsPane: View {
    let hasBattery: Bool

    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(PreferenceKeys.menuBarIconScale) private var menuBarIconScale = MenuBarIconSize.defaultScale
    @AppStorage(PreferenceKeys.ringContent) private var ringContentRaw = RingContent.defaultValue.rawValue
    @AppStorage(PreferenceKeys.ringPressureOverride) private var ringPressureOverride = true
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    @AppStorage(PreferenceKeys.adaptiveRingPriority) private var adaptiveRingPriorityRaw = PerformancePreference.automatic.rawValue
    @AppStorage(PreferenceKeys.adaptiveRingColorCoding) private var adaptiveRingColorCoding = false

    var body: some View {
        SettingsPaneForm {
            Section {
                Toggle(localized("Enable animations"), isOn: $animationsEnabled)

                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("Icon Size"))
                    HStack(spacing: 10) {
                        Text(localized("Small"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(
                            value: resolvedMenuBarIconScale,
                            in: MenuBarIconSize.minimumScale...MenuBarIconSize.maximumScale,
                            step: MenuBarIconSize.step
                        )
                        .accessibilityLabel(localized("Menu bar icon size"))
                        .accessibilityValue(localized("%d%%", Int((MenuBarIconSize.resolve(menuBarIconScale) * 100).rounded())))
                        Text(localized("Large"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(localized("Adjust DuoBar to better match your menu bar."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(localized("Outer Ring")) {
                Picker(localized("Ring shows"), selection: ringContent) {
                    ForEach(RingContent.options(hasBattery: hasBattery)) { content in
                        Text(content.localizedDisplayName).tag(content)
                    }
                }

                if resolvedRingContent.isFixedMetric {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(localized("Show high load alerts"), isOn: $ringPressureOverride)
                        Text(localized("Sustained CPU, memory, or thermal pressure temporarily takes over the ring."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if showsBatteryOptions {
                    Toggle(localized("Battery Color Coding"), isOn: $batteryColorCoding)
                }

                if showsPressureOptions {
                    Picker(localized("Adaptive Ring Priority"), selection: adaptiveRingPriority) {
                        ForEach(PerformancePreference.allCases, id: \.self) { preference in
                            Text(preference.localizedDisplayName).tag(preference)
                        }
                    }
                    Text(localized("Used only when multiple system conditions need attention. Critical conditions can still take priority."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(localized("Adaptive Ring Color Coding"), isOn: $adaptiveRingColorCoding)
                }
            }
        }
    }

    private var resolvedRingContent: RingContent {
        let content = RingContent(rawValue: ringContentRaw) ?? .defaultValue
        return RingContent.options(hasBattery: hasBattery).contains(content) ? content : .defaultValue
    }

    private var showsBatteryOptions: Bool {
        hasBattery && !resolvedRingContent.isFixedMetric
    }

    private var showsPressureOptions: Bool {
        resolvedRingContent.isFixedMetric ? ringPressureOverride : !hasBattery
    }

    private var ringContent: Binding<RingContent> {
        Binding(
            get: { resolvedRingContent },
            set: { ringContentRaw = $0.rawValue }
        )
    }

    private var resolvedMenuBarIconScale: Binding<Double> {
        Binding(
            get: { MenuBarIconSize.resolve(menuBarIconScale) },
            set: { menuBarIconScale = MenuBarIconSize.resolve($0) }
        )
    }

    private var adaptiveRingPriority: Binding<PerformancePreference> {
        Binding(
            get: { PerformancePreference(rawValue: adaptiveRingPriorityRaw) ?? .automatic },
            set: { adaptiveRingPriorityRaw = $0.rawValue }
        )
    }
}
