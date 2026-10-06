import Foundation

public enum PopoverModule: String, CaseIterable, Identifiable, Sendable {
    case network
    case volume
    case battery
    case audioOutput
    case audioInput
    case systemLoad
    case keepAwake
    case diskSpace

    public var id: Self { self }



    public var requiresBattery: Bool {
        self == .battery
    }
}

public struct PopoverLayout: Equatable, Sendable {
    private init(entries: [Entry], hasBattery: Bool) {
        self.entries = entries
        self.hasBattery = hasBattery
    }

    public struct Entry: Equatable, Identifiable, Sendable {
        public init(module: PopoverModule, isVisible: Bool) {
            self.module = module
            self.isVisible = isVisible
        }

        public var module: PopoverModule
        public var isVisible: Bool

        public var id: PopoverModule { module }
    }

    public private(set) var entries: [Entry]
    private let hasBattery: Bool

    public var visibleModules: [PopoverModule] {
        entries
            .filter { $0.isVisible && (hasBattery || !$0.module.requiresBattery) }
            .map(\.module)
    }

    public var storageValue: String {
        entries.map { "\($0.module.rawValue):\($0.isVisible ? 1 : 0)" }.joined(separator: ",")
    }

    public static func resolve(stored: String?, hasBattery: Bool) -> PopoverLayout {
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

    public func configurableEntries(hasBattery: Bool) -> [Entry] {
        entries.filter { hasBattery || !$0.module.requiresBattery }
    }

    public mutating func moveConfigurable(fromOffsets source: IndexSet, toOffset destination: Int, hasBattery: Bool) {
        var shown = configurableEntries(hasBattery: hasBattery)
        let hidden = entries.filter { entry in !shown.contains(entry) }
        let moving = source.map { shown[$0] }
        let insertion = destination - source.filter { $0 < destination }.count
        shown = shown.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        shown.insert(contentsOf: moving, at: min(max(insertion, 0), shown.count))
        entries = shown + hidden
    }

    public mutating func setVisible(_ isVisible: Bool, for module: PopoverModule) {
        guard let index = entries.firstIndex(where: { $0.module == module }) else { return }
        entries[index].isVisible = isVisible
    }
}
