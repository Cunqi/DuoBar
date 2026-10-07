import DuoBarCore
import DuoBarKit
import SwiftUI

struct AudioInputSection: View {
    @ObservedObject var switcher: AudioDeviceSwitcher

    var body: some View {
        PopoverCard(canExpand: switcher.inputs.count > 1) {
            VStack(alignment: .leading, spacing: 4) {
                PopoverCardHeader(
                    symbol: symbol,
                    title: localized("Audio Input"),
                    detail: switcher.inputFeedback?.message ?? switcher.defaultInput?.name ?? localized("No input device")
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
            AudioDeviceList(options: switcher.inputs.map { AudioDeviceListOption(id: $0.id, name: $0.name, isDefault: $0.isDefault) }) { selected in
                guard let option = switcher.inputs.first(where: { $0.id == selected.id }) else { return }
                switcher.setDefault(option, direction: .input)
            }
        }
    }

    private var symbol: String {
        guard let volume = switcher.inputVolume else { return "mic" }
        return volume <= 0.001 ? "mic.slash" : "mic"
    }
}
