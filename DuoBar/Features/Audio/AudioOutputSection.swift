import DuoBarCore
import DuoBarKit
import SwiftUI

struct AudioOutputSection: View {
    let symbol: String
    let detail: String
    let stateText: String
    @ObservedObject var switcher: AudioDeviceSwitcher

    var body: some View {
        PopoverCard(canExpand: switcher.outputs.count > 1) {
            PopoverCardHeader(symbol: symbol, title: localized("Audio Output"), detail: detail, stateText: stateText)
        } expanded: {
            AudioDeviceList(options: switcher.outputs.map { AudioDeviceListOption(id: $0.id, name: $0.name, isDefault: $0.isDefault) }) { selected in
                guard let option = switcher.outputs.first(where: { $0.id == selected.id }) else { return }
                switcher.setDefault(option, direction: .output)
            }
        }
    }
}
