import Foundation

enum PopoverModule: String, CaseIterable, Identifiable, Sendable {
    case network
    case volume
    case battery
    case audioOutput
    case audioInput
    case systemLoad
    case keepAwake
    case diskSpace

    var id: Self { self }

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

    var requiresBattery: Bool {
        self == .battery
    }
}

struct PopoverLayout: Equatable, Sendable {
    struct Entry: Equatable, Identifiable, Sendable {
        var module: PopoverModule
        var isVisible: Bool

        var id: PopoverModule { module }
    }

    private(set) var entries: [Entry]
    private let hasBattery: Bool

    var visibleModules: [PopoverModule] {
        entries
            .filter { $0.isVisible && (hasBattery || !$0.module.requiresBattery) }
            .map(\.module)
    }

    var storageValue: String {
        entries.map { "\($0.module.rawValue):\($0.isVisible ? 1 : 0)" }.joined(separator: ",")
    }

    static func resolve(stored: String?, hasBattery: Bool) -> PopoverLayout {
        var entries: [Entry] = []
        for component in (stored ?? "").split(separator: ",") {
            let parts = component.split(separator: ":")
            guard parts.count == 2,
                  let module = PopoverModule(rawValue: String(parts[0])),
                  let flag = Int(parts[1]),
                  !entries.contains(where: { $0.module == module })
            else { continue }
            entries.append(Entry(module: module, isVisible: flag != 0))
        }
        for module in PopoverModule.allCases where !entries.contains(where: { $0.module == module }) {
            entries.append(Entry(module: module, isVisible: hasBattery || !module.requiresBattery))
        }
        return PopoverLayout(entries: entries, hasBattery: hasBattery)
    }

    func configurableEntries(hasBattery: Bool) -> [Entry] {
        entries.filter { hasBattery || !$0.module.requiresBattery }
    }

    mutating func moveConfigurable(fromOffsets source: IndexSet, toOffset destination: Int, hasBattery: Bool) {
        var shown = configurableEntries(hasBattery: hasBattery)
        let hidden = entries.filter { entry in !shown.contains(entry) }
        let moving = source.map { shown[$0] }
        let insertion = destination - source.filter { $0 < destination }.count
        shown = shown.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        shown.insert(contentsOf: moving, at: min(max(insertion, 0), shown.count))
        entries = shown + hidden
    }

    mutating func setVisible(_ isVisible: Bool, for module: PopoverModule) {
        guard let index = entries.firstIndex(where: { $0.module == module }) else { return }
        entries[index].isVisible = isVisible
    }
}
