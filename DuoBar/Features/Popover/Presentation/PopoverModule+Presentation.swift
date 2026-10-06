import Foundation
import DuoBarCore

extension PopoverModule {
    var localizedDisplayName: String {
        switch self {
        case .network: localized("Network")
        case .volume: localized("Volume")
        case .battery: localized("Battery")
        case .audioOutput: localized("Audio Output")
        case .audioInput: localized("Audio Input")
        case .systemLoad: localized("System Load")
        case .keepAwake: localized("Keep Awake")
        case .diskSpace: localized("Disk Space")
        }
    }

    var symbol: String {
        switch self {
        case .network: "wifi"
        case .volume: "speaker.wave.2"
        case .battery: "battery.75percent"
        case .audioOutput: "hifispeaker"
        case .audioInput: "mic"
        case .systemLoad: "cpu"
        case .keepAwake: "cup.and.saucer"
        case .diskSpace: "internaldrive"
        }
    }
}
