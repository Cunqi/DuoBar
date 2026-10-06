import Foundation

public enum AudioDeviceTransport: Equatable, Sendable {
    case builtIn
    case bluetooth
    case bluetoothLE
    case airPlay
    case usb
    case hdmi
    case displayPort
    case virtual
    case other

    public var isBluetooth: Bool {
        self == .bluetooth || self == .bluetoothLE
    }
}
public enum AudioDeviceGlyph: Equatable, Sendable {
    case airPods
    case headphones
}
public enum AudioConnectionGlyph: Equatable, Sendable {
    case airPodsPro
    case airPodsMax
    case airPods
    case headphones
    case audioDevice
}
public enum AudioDeviceTerminalType: Equatable, Sendable {
    case headphones
    case other(UInt32)
    case unavailable
}
public struct AudioDeviceStatus: Equatable, Sendable, Identifiable {
    public init(
        uid: String,
        name: String,
        transport: AudioDeviceTransport,
        isAlive: Bool,
        modelUID: String? = nil,
        manufacturer: String? = nil,
        terminalType: AudioDeviceTerminalType = .unavailable
    ) {
        self.uid = uid
        self.name = name
        self.transport = transport
        self.isAlive = isAlive
        self.modelUID = modelUID
        self.manufacturer = manufacturer
        self.terminalType = terminalType
    }

    public var id: String { uid }

    public var uid: String
    public var name: String
    public var transport: AudioDeviceTransport
    public var isAlive: Bool
    public var modelUID: String? = nil
    public var manufacturer: String? = nil
    public var terminalType: AudioDeviceTerminalType = .unavailable

    public var temporaryGlyph: AudioDeviceGlyph {
        let normalizedName = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return normalizedName.contains("airpods") ? .airPods : .headphones
    }

    public var temporaryConnectionGlyph: AudioConnectionGlyph {
        if normalizedModelUID == "2027 4c" {
            return .airPodsPro
        }

        let isBluetoothHeadphones = transport.isBluetooth && terminalType == .headphones
        let isApple = normalizedManufacturer.contains("apple")
        guard isBluetoothHeadphones else {
            return transport.isBluetooth ? .headphones : .audioDevice
        }

        if isApple, normalizedName.contains("airpods pro") {
            return .airPodsPro
        }
        if normalizedName.contains("airpods max") {
            return .airPodsMax
        }
        if normalizedName.contains("airpods") {
            return .airPods
        }
        return .headphones
    }

    private var normalizedName: String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private var normalizedManufacturer: String {
        manufacturer?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) ?? ""
    }

    private var normalizedModelUID: String {
        modelUID?
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ") ?? ""
    }
}
public struct AudioStatus: Equatable, Sendable {
    public init(
        isAvailable: Bool,
        defaultOutput: AudioDeviceStatus?,
        volume: OutputVolumeStatus,
        connectedBluetoothOutputs: [AudioDeviceStatus]
    ) {
        self.isAvailable = isAvailable
        self.defaultOutput = defaultOutput
        self.volume = volume
        self.connectedBluetoothOutputs = connectedBluetoothOutputs
    }

    public var isAvailable: Bool
    public var defaultOutput: AudioDeviceStatus?
    public var volume: OutputVolumeStatus
    public var connectedBluetoothOutputs: [AudioDeviceStatus]

    public static let unavailable = AudioStatus(
        isAvailable: false,
        defaultOutput: nil,
        volume: .unavailable,
        connectedBluetoothOutputs: []
    )

    public var connectedAudioDevice: AudioDeviceStatus? {
        if let defaultOutput, defaultOutput.transport.isBluetooth {
            return defaultOutput
        }
        return connectedBluetoothOutputs.first ?? defaultOutput
    }
}
