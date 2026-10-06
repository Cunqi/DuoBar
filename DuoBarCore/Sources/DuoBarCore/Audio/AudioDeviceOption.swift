import Foundation

public enum AudioDeviceDirection: Sendable {
    case output
    case input
}

public struct AudioDeviceDescriptor: Equatable, Sendable {
    public init(
        id: UInt32,
        name: String,
        hasOutput: Bool,
        hasInput: Bool
    ) {
        self.id = id
        self.name = name
        self.hasOutput = hasOutput
        self.hasInput = hasInput
    }

    public var id: UInt32
    public var name: String
    public var hasOutput: Bool
    public var hasInput: Bool
}

public struct AudioDeviceOption: Identifiable, Equatable, Sendable {
    public init(
        id: UInt32,
        name: String,
        isDefault: Bool
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }

    public var id: UInt32
    public var name: String
    public var isDefault: Bool

    public static func options(
        from descriptors: [AudioDeviceDescriptor],
        direction: AudioDeviceDirection,
        defaultID: UInt32?
    ) -> [AudioDeviceOption] {
        descriptors
            .filter { direction == .output ? $0.hasOutput : $0.hasInput }
            .map { AudioDeviceOption(id: $0.id, name: $0.name, isDefault: $0.id == defaultID) }
    }
}
