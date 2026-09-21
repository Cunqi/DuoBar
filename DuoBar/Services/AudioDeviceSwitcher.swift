import CoreAudio
import Foundation

@MainActor
final class AudioDeviceSwitcher: ObservableObject {
    @Published private(set) var outputs: [AudioDeviceOption] = []
    @Published private(set) var inputs: [AudioDeviceOption] = []
    @Published private(set) var inputVolume: Double?
    @Published private(set) var isInputVolumeSettable = false

    private static let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private let listenerQueue = DispatchQueue(label: "com.mikeli.duobar.audio-device-switcher")
    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var inputVolumeListenerDevice: AudioDeviceID?

    var defaultInput: AudioDeviceOption? {
        inputs.first(where: \.isDefault)
    }

    func start() {
        guard listeners.isEmpty else {
            refresh()
            return
        }
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultInputDevice] {
            addListener(objectID: Self.systemObject, address: Self.globalAddress(selector))
        }
        refresh()
    }

    func stop() {
        for (objectID, address, block) in listeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(objectID, &address, listenerQueue, block)
        }
        listeners.removeAll()
        inputVolumeListenerDevice = nil
    }

    func setDefault(_ option: AudioDeviceOption, direction: AudioDeviceDirection) {
        var address = Self.globalAddress(direction == .output ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice)
        var deviceID = option.id
        AudioObjectSetPropertyData(Self.systemObject, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID)
        refresh()
    }

    func setInputVolume(_ level: Double) {
        guard let deviceID = defaultInput?.id else { return }
        var scalar = Float32(min(max(level, 0), 1))
        for var address in Self.inputVolumeAddresses(deviceID: deviceID) {
            AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &scalar)
        }
        inputVolume = Double(scalar)
    }

    private func refresh() {
        let descriptors = Self.readDeviceIDs().compactMap(Self.describe)
        outputs = AudioDeviceOption.options(from: descriptors, direction: .output, defaultID: Self.readDefault(kAudioHardwarePropertyDefaultOutputDevice))
        inputs = AudioDeviceOption.options(from: descriptors, direction: .input, defaultID: Self.readDefault(kAudioHardwarePropertyDefaultInputDevice))
        refreshInputVolume()
    }

    private func refreshInputVolume() {
        guard let deviceID = defaultInput?.id else {
            inputVolume = nil
            isInputVolumeSettable = false
            return
        }
        let addresses = Self.inputVolumeAddresses(deviceID: deviceID)
        let values = addresses.compactMap { address -> Float32? in
            var address = address
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            return AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr ? value : nil
        }
        inputVolume = values.isEmpty ? nil : Double(values.reduce(0, +) / Float32(values.count))
        isInputVolumeSettable = !addresses.isEmpty && addresses.allSatisfy { address in
            var address = address
            var settable = DarwinBoolean(false)
            return AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr && settable.boolValue
        }
        if inputVolumeListenerDevice != deviceID, let address = addresses.first {
            inputVolumeListenerDevice = deviceID
            addListener(objectID: deviceID, address: address)
        }
    }

    private func addListener(objectID: AudioObjectID, address: AudioObjectPropertyAddress) {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
        var address = address
        guard AudioObjectAddPropertyListenerBlock(objectID, &address, listenerQueue, block) == noErr else { return }
        listeners.append((objectID, address, block))
    }

    private static func globalAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    private static func readDefault(_ selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        var address = globalAddress(selector)
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &deviceID) == noErr,
              deviceID != kAudioObjectUnknown
        else { return nil }
        return deviceID
    }

    private static func readDeviceIDs() -> [AudioDeviceID] {
        var address = globalAddress(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: kAudioObjectUnknown, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func describe(_ deviceID: AudioDeviceID) -> AudioDeviceDescriptor? {
        var address = globalAddress(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name) == noErr,
              let name = name?.takeRetainedValue() as String?
        else { return nil }
        return AudioDeviceDescriptor(
            id: deviceID,
            name: name,
            hasOutput: hasStreams(deviceID, scope: kAudioDevicePropertyScopeOutput),
            hasInput: hasStreams(deviceID, scope: kAudioDevicePropertyScopeInput)
        )
    }

    private static func hasStreams(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func inputVolumeAddresses(deviceID: AudioDeviceID) -> [AudioObjectPropertyAddress] {
        let main = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        var probe = main
        if AudioObjectHasProperty(deviceID, &probe) {
            return [main]
        }
        return [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)].compactMap { channel in
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeInput, mElement: channel)
            return AudioObjectHasProperty(deviceID, &address) ? address : nil
        }
    }
}
