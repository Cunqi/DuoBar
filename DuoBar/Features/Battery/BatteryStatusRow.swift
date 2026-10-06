import DuoBarCore
import SwiftUI

struct BatteryStatusRow: View {
    let battery: BatteryStatus
    let showPercentage: Bool

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 8) {
                    Text(localized("Battery"))
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer(minLength: 8)
                    if let trailingValue {
                        Text(trailingValue)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    var trailingValue: String? {
        guard showPercentage, let percentage = battery.percentage else { return nil }
        return localized("%d%%", percentage)
    }

    var detail: String {
        guard battery.isAvailable else { return localized("No internal battery") }
        if battery.isFullyCharged { return localized("Fully charged") }
        if battery.isCharging { return localized("Charging") }
        if battery.isLowPowerModeEnabled { return localized("Low Power Mode") }
        if battery.isPluggedIn { return localized("Power adapter connected") }
        return localized("Using battery power")
    }

    private var symbol: String {
        if battery.isCharging { return "battery.100percent.bolt" }
        if battery.isFullyCharged { return "battery.100percent" }
        switch battery.percentage ?? 0 {
        case 76...100: return "battery.100percent"
        case 51...75: return "battery.75percent"
        case 26...50: return "battery.50percent"
        default: return "battery.25percent"
        }
    }
}
